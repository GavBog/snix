use super::{PathInfo, PathInfoService};
use crate::nar::ingest_nar_and_hash;
use futures::{TryStreamExt, stream::BoxStream};
use nix_compat::{
    narinfo::{self, NarInfo, Signature},
    nixbase32,
    nixhash::NixHash,
    store_path::StorePath,
};
use reqwest::StatusCode;
use snix_castore::composition::{CompositionContext, ServiceBuilder};
use snix_castore::{Error, blobservice::BlobService, directoryservice::DirectoryService};
use std::sync::Arc;
use tokio::io::{self, AsyncRead};
use tonic::async_trait;
use tracing::{debug, instrument, warn};
use url::Url;

/// NixHTTPPathInfoService acts as a bridge in between the Nix HTTP Binary cache
/// protocol provided by Nix binary caches such as cache.nixos.org, and the Snix
/// Store Model.
/// It implements the [PathInfoService] trait in an interesting way:
/// Every [PathInfoService::get] fetches the .narinfo and referred NAR file,
/// inserting components into a [BlobService] and [DirectoryService], then
/// returning a [PathInfo] struct with the root.
///
/// Due to this being quite a costly operation, clients are expected to layer
/// this service with store composition, so they're only ingested once.
///
/// The client is expected to be (indirectly) using the same [BlobService] and
/// [DirectoryService], so able to fetch referred Directories and Blobs.
/// [PathInfoService::put] is not implemented and returns an error if called.
/// TODO: what about reading from nix-cache-info?
pub struct NixHTTPPathInfoService<BS, DS> {
    instance_name: String,
    base_url: url::Url,
    http_client: reqwest_middleware::ClientWithMiddleware,

    blob_service: BS,
    directory_service: DS,

    /// An optional list of [narinfo::VerifyingKey].
    /// If the list is not empty, the .narinfo files received need to have
    /// correct signature by at least one of these.
    trusted_public_keys: Vec<narinfo::VerifyingKey>,
}

impl<BS, DS> NixHTTPPathInfoService<BS, DS> {
    pub fn try_build(
        instance_name: String,
        config: NixHTTPPathInfoServiceConfig,
        blob_service: BS,
        directory_service: DS,
    ) -> Result<Self, Error> {
        let mut trusted_public_keys = Vec::new();
        for s in config.params.trusted_public_keys {
            trusted_public_keys.push(
                narinfo::VerifyingKey::parse(&s)
                    .map_err(|e| Error::StorageError(format!("invalid public key: {e}")))?,
            )
        }

        Ok(Self {
            instance_name,
            base_url: config.base_url,
            http_client: reqwest_middleware::ClientBuilder::new(
                reqwest::Client::builder()
                    .user_agent(crate::USER_AGENT)
                    .build()
                    .expect("Client::new()"),
            )
            .with(snix_tracing::propagate::reqwest::tracing_middleware())
            .build(),
            blob_service,
            directory_service,

            trusted_public_keys,
        })
    }
}

#[async_trait]
impl<BS, DS> PathInfoService for NixHTTPPathInfoService<BS, DS>
where
    BS: BlobService + Send + Sync + Clone + 'static,
    DS: DirectoryService + Send + Sync + Clone + 'static,
{
    #[instrument(skip_all, err, fields(path.digest=nixbase32::encode(&digest), instance_name=%self.instance_name))]
    async fn get(&self, digest: [u8; 20]) -> Result<Option<PathInfo>, Error> {
        let narinfo_url = self
            .base_url
            .join(&format!("{}.narinfo", nixbase32::encode(&digest)))
            .map_err(|e| {
                warn!(e = %e, "unable to join URL");
                io::Error::new(io::ErrorKind::InvalidInput, "unable to join url")
            })?;

        debug!(narinfo_url= %narinfo_url, "constructed NARInfo url");

        let resp = self
            .http_client
            .get(narinfo_url)
            .send()
            .await
            .map_err(|e| {
                warn!(e=%e,"unable to send NARInfo request");
                io::Error::new(
                    io::ErrorKind::InvalidInput,
                    "unable to send NARInfo request",
                )
            })?;

        // In the case of a 404, return a NotFound.
        // We also return a NotFound in case of a 403 - this is to match the behaviour as Nix,
        // when querying nix-cache.s3.amazonaws.com directly, rather than cache.nixos.org.
        if resp.status() == StatusCode::NOT_FOUND || resp.status() == StatusCode::FORBIDDEN {
            return Ok(None);
        }

        let narinfo_str = resp.text().await.map_err(|e| {
            warn!(e=%e,"unable to decode response as string");
            io::Error::new(
                io::ErrorKind::InvalidData,
                "unable to decode response as string",
            )
        })?;

        // parse the received narinfo
        let narinfo = NarInfo::parse(&narinfo_str).map_err(|e| {
            warn!(e=%e,"unable to parse response as NarInfo");
            io::Error::new(
                io::ErrorKind::InvalidData,
                "unable to parse response as NarInfo",
            )
        })?;

        // if [self.trusted_public_keys] is set, ensure there's at least one valid signature.
        if !self.trusted_public_keys.is_empty() {
            let fingerprint = narinfo.fingerprint();

            if !self.trusted_public_keys.iter().any(|pubkey| {
                narinfo
                    .signatures
                    .iter()
                    .any(|sig| pubkey.verify(&fingerprint, sig))
            }) {
                warn!("no valid signature found");
                Err(io::Error::new(
                    io::ErrorKind::InvalidData,
                    "no valid signature found",
                ))?;
            }
        }

        // To construct the full PathInfo, we also need to populate the node field,
        // and for this we need to download the NAR file and ingest it into castore.
        // FUTUREWORK: Keep some database around mapping from narsha256 to
        // (unnamed) rootnode, so we can use that (and the name from the
        // StorePath) and avoid downloading the same NAR a second time.

        // create a request for the NAR file itself.
        let nar_url = self.base_url.join(narinfo.url).map_err(|e| {
            warn!(e = %e, "unable to join URL");
            io::Error::new(io::ErrorKind::InvalidInput, "unable to join url")
        })?;
        debug!(nar_url= %nar_url, "constructed NAR url");

        let resp = self
            .http_client
            .get(nar_url.clone())
            .send()
            .await
            .map_err(|e| {
                warn!(e=%e,"unable to send NAR request");
                io::Error::new(io::ErrorKind::InvalidInput, "unable to send NAR request")
            })?;

        // if the request is not successful, return an error.
        if !resp.status().is_success() {
            return Err(Error::StorageError(format!(
                "unable to retrieve NAR at {}, status {}",
                nar_url,
                resp.status()
            )));
        }

        // get a reader of the response body.
        let r = tokio_util::io::StreamReader::new(resp.bytes_stream().map_err(|e| {
            let e = e.without_url();
            warn!(e=%e, "failed to get response body");
            io::Error::new(io::ErrorKind::BrokenPipe, e.to_string())
        }));

        // handle decompression, depending on the compression field.
        let mut r: Box<dyn AsyncRead + Send + Unpin> = match narinfo.compression {
            None => Box::new(r) as Box<dyn AsyncRead + Send + Unpin>,
            Some("bzip2") => Box::new(async_compression::tokio::bufread::BzDecoder::new(r))
                as Box<dyn AsyncRead + Send + Unpin>,
            Some("gzip") => Box::new(async_compression::tokio::bufread::GzipDecoder::new(r))
                as Box<dyn AsyncRead + Send + Unpin>,
            Some("xz") => Box::new(async_compression::tokio::bufread::XzDecoder::new(r))
                as Box<dyn AsyncRead + Send + Unpin>,
            Some("zstd") => Box::new(async_compression::tokio::bufread::ZstdDecoder::new(r))
                as Box<dyn AsyncRead + Send + Unpin>,
            Some(comp_str) => {
                return Err(Error::StorageError(format!(
                    "unsupported compression: {comp_str}"
                )));
            }
        };

        let (root_node, nar_hash, nar_size) = ingest_nar_and_hash(
            self.blob_service.clone(),
            &self.directory_service,
            &mut r,
            &narinfo.ca,
        )
        .await
        .map_err(io::Error::other)?;

        // ensure the ingested narhash and narsize do actually match.
        if narinfo.nar_size != nar_size {
            warn!(
                narinfo.nar_size = narinfo.nar_size,
                http.nar_size = nar_size,
                "NarSize mismatch"
            );
            Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "NarSize mismatch".to_string(),
            ))?;
        }
        if narinfo.nar_hash != nar_hash {
            warn!(
                narinfo.nar_hash = %NixHash::Sha256(narinfo.nar_hash),
                http.nar_hash = %NixHash::Sha256(nar_hash),
                "NarHash mismatch"
            );
            Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "NarHash mismatch".to_string(),
            ))?;
        }

        Ok(Some(PathInfo {
            store_path: narinfo.store_path.to_owned(),
            node: root_node,
            references: narinfo.references.iter().map(StorePath::to_owned).collect(),
            nar_size: narinfo.nar_size,
            nar_sha256: narinfo.nar_hash,
            deriver: narinfo.deriver.as_ref().map(StorePath::to_owned),
            signatures: narinfo
                .signatures
                .into_iter()
                .map(|s| Signature::<String>::new(s.name().to_string(), s.bytes().to_owned()))
                .collect(),
            ca: narinfo.ca,
        }))
    }

    #[instrument(skip_all, fields(path_info=?_path_info, instance_name=%self.instance_name))]
    async fn put(&self, _path_info: PathInfo) -> Result<PathInfo, Error> {
        Err(Error::InvalidRequest(
            "put not supported for this backend".to_string(),
        ))
    }

    fn list(&self) -> BoxStream<'static, Result<PathInfo, Error>> {
        Box::pin(futures::stream::once(async {
            Err(Error::InvalidRequest(
                "list not supported for this backend".to_string(),
            ))
        }))
    }
}

#[derive(serde::Deserialize, Clone, Debug, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct NixHTTPPathInfoServiceConfig {
    base_url: Url,

    #[serde(flatten)]
    params: NixHTTPPathInfoServiceParams,
}

#[derive(serde::Deserialize, Clone, Debug, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
struct NixHTTPPathInfoServiceParams {
    #[serde(default = "default_blob_service")]
    blob_service: String,
    #[serde(default = "default_directory_service")]
    directory_service: String,
    #[serde(default)]
    /// An optional list of [narinfo::VerifyingKey].
    /// If not empty, the .narinfo files received need to have correct signature by at least one of these.
    trusted_public_keys: Vec<String>,
}

fn default_blob_service() -> String {
    "&root".to_string()
}
fn default_directory_service() -> String {
    "&root".to_string()
}

impl TryFrom<Url> for NixHTTPPathInfoServiceConfig {
    type Error = Box<dyn std::error::Error + Send + Sync>;
    fn try_from(url: Url) -> Result<Self, Self::Error> {
        let scheme = url
            .scheme()
            .strip_prefix("nix+")
            .ok_or_else(|| Error::StorageError("scheme must start with nix+".to_string()))?;

        if !url.has_authority() {
            Err(Error::StorageError(
                "url must have authority component".to_string(),
            ))?
        }
        if !url.has_host() {
            Err(Error::StorageError(
                "url must have host component".to_string(),
            ))?
        }
        if !["http", "https"].contains(&scheme) {
            Err(Error::StorageError("unknown scheme".to_string()))?
        }

        Ok(NixHTTPPathInfoServiceConfig {
            // Stringify the URL and remove the nix+ prefix.
            // We can't use `url.set_scheme(rest)`, as it disallows
            // setting something http(s) that previously wasn't.
            // Also make sure to drop the query, we don't want to leak our
            // config to the remote HTTP endpoint we query.
            base_url: {
                let mut url: Url = url
                    .to_string()
                    .strip_prefix("nix+")
                    .unwrap()
                    .parse()
                    .expect("stripped URL to parse again");
                url.set_query(None);
                url
            },
            params: serde_qs::from_str(url.query().unwrap_or_default())
                .map_err(|e| Error::InvalidRequest(format!("failed to parse parameters: {e}")))?,
        })
    }
}

#[async_trait]
impl ServiceBuilder for NixHTTPPathInfoServiceConfig {
    type Output = dyn PathInfoService;
    async fn build<'a>(
        &'a self,
        instance_name: &str,
        context: &CompositionContext,
    ) -> Result<Arc<Self::Output>, Box<dyn std::error::Error + Send + Sync + 'static>> {
        let (blob_service, directory_service) = futures::join!(
            context.resolve::<dyn BlobService>(&self.params.blob_service),
            context.resolve::<dyn DirectoryService>(&self.params.directory_service)
        );
        let svc = NixHTTPPathInfoService::try_build(
            instance_name.to_string(),
            self.to_owned(),
            blob_service?,
            directory_service?,
        )?;
        Ok(Arc::new(svc))
    }
}

#[cfg(test)]
mod tests {
    use super::{NixHTTPPathInfoServiceConfig, NixHTTPPathInfoServiceParams};
    use rstest::rstest;
    use url::Url;

    #[rstest]
    /// Correct Scheme for the cache.nixos.org binary cache.
    #[case::correct_nix_https("nix+https://cache.nixos.org", Some(
        NixHTTPPathInfoServiceConfig {
            base_url: "https://cache.nixos.org".try_into().unwrap(),
            params: NixHTTPPathInfoServiceParams {
                blob_service: "&root".to_string(),
                directory_service: "&root".to_string(),
                trusted_public_keys: vec![]
            }
        }
    ))]
    /// Correct Scheme for the cache.nixos.org binary cache (HTTP URL).
    #[case::correct_nix_http("nix+http://cache.nixos.org", Some(
        NixHTTPPathInfoServiceConfig {
            base_url: "http://cache.nixos.org".try_into().unwrap(),
            params: NixHTTPPathInfoServiceParams {
                blob_service: "&root".to_string(),
                directory_service: "&root".to_string(),
                trusted_public_keys: vec![]
            }
        }
    ))]
    /// Correct Scheme for Nix HTTP Binary cache, with a subpath.
    #[case::correct_nix_http_with_subpath("nix+http://192.0.2.1/foo", Some(
        NixHTTPPathInfoServiceConfig {
            base_url: "http://192.0.2.1/foo".try_into().unwrap(),
            params: NixHTTPPathInfoServiceParams {
                blob_service: "&root".to_string(),
                directory_service: "&root".to_string(),
                trusted_public_keys: vec![]
            }
        }
    ))]
    /// Correct Scheme for Nix HTTP Binary cache, with a subpath and port.
    #[case::correct_nix_http_with_subpath_and_port("nix+http://[::1]:8080/foo", Some(
        NixHTTPPathInfoServiceConfig {
            base_url: "http://[::1]:8080/foo".try_into().unwrap(),
            params: NixHTTPPathInfoServiceParams {
                blob_service: "&root".to_string(),
                directory_service: "&root".to_string(),
                trusted_public_keys: vec![]
            }
        }

    ))]
    /// Correct Scheme for the cache.nixos.org binary cache, and correct trusted public key set
    #[case::correct_nix_https_with_trusted_public_key(
        "nix+https://cache.nixos.org?trusted_public_keys[0]=cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=", Some(
        NixHTTPPathInfoServiceConfig {
            base_url: "https://cache.nixos.org".try_into().unwrap(),
            params: NixHTTPPathInfoServiceParams {
                blob_service: "&root".to_string(),
                directory_service: "&root".to_string(),
                trusted_public_keys: vec![
                    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=".to_string()
                ]
            }
        }
    ))]
    /// Correct Scheme for the cache.nixos.org binary cache, and two correct trusted public keys set
    #[case::correct_nix_https_with_two_trusted_public_keys(
        "nix+https://cache.nixos.org?trusted_public_keys[0]=cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=&trusted_public_keys[1]=foo:jp4fCEx9tBEId/L0ZsVJ26k0wC0fu7vJqLjjIGFkup8=", Some(
        NixHTTPPathInfoServiceConfig {
            base_url: "https://cache.nixos.org".try_into().unwrap(),
            params: NixHTTPPathInfoServiceParams {
                blob_service: "&root".to_string(),
                directory_service: "&root".to_string(),
                trusted_public_keys: vec![
                    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=".to_string(),
                    "foo:jp4fCEx9tBEId/L0ZsVJ26k0wC0fu7vJqLjjIGFkup8=".to_string()
                ]
            }
        }
    ))]
    #[case::wrong_scheme("nix+grpc://example.com", None)]
    #[case::missing_host("nix+http:///", None)]
    #[case::missing_authority("nix+http:", None)]
    /// Correct cache.nixos.org binary cache URL, but wrong `trusted_public_keys` param usage (should be list)
    #[case::trusted_public_keys_no_sequence(
        "nix+https://cache.nixos.org?trusted_public_keys=cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=",
        None
    )]
    /// Correct cache.nixos.org binary cache URL, but wrong param name
    #[case::trusted_public_keys_wrong_pubkey(
        "nix+https://cache.nixos.org?trustedpublickeys=cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=",
        None
    )]
    fn parse_url(#[case] url_str: &str, #[case] exp_config: Option<NixHTTPPathInfoServiceConfig>) {
        let url: Url = url_str.parse().expect("url to parse");

        match (NixHTTPPathInfoServiceConfig::try_from(url), exp_config) {
            (Ok(_), None) => panic!("parsing url unexpectedly succeeded"),
            (Ok(config), Some(exp_config)) => assert_eq!(exp_config, config),
            (Err(_), None) => {}
            (Err(e), Some(_)) => panic!("parsing url unexpectedly failed: {e}"),
        }
    }
}
