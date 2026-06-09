use std::path::PathBuf;

use hyper_util::rt::TokioIo;
use serde::{
    Deserialize, Deserializer,
    de::{self, Unexpected},
};
use tokio::net::UnixStream;
use tonic::transport::{Channel, Endpoint};

#[derive(Debug)]
pub struct TonicConnector {
    transport: Transport,
    url_params: URLParams,
}

#[derive(Debug)]
enum Transport {
    HTTP2 {
        url: String,
        /// The option signals if TLS itself is configured or not.
        tls_config_params: Option<TLSConfigParams>,
    },
    UnixDomainSocket {
        path: PathBuf,
    },
}

#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "kebab-case")]
struct URLParams {
    /// Whether to connect eagerly
    #[serde(deserialize_with = "bool_from_int", default)]
    wait_connect: bool,
}

fn bool_from_int<'de, D>(deserializer: D) -> Result<bool, D::Error>
where
    D: Deserializer<'de>,
{
    match u8::deserialize(deserializer)? {
        0 => Ok(false),
        1 => Ok(true),
        other => Err(de::Error::invalid_value(
            Unexpected::Unsigned(other as u64),
            &"zero or one",
        )),
    }
}

#[derive(Debug, Default, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "kebab-case")]
struct TLSConfigParams {
    tls_client_cert_path: Option<PathBuf>,
    tls_client_key_path: Option<PathBuf>,
    tls_ca_cert_path: Option<PathBuf>,
}

/// TLS Config with already read files.
#[derive(Debug, Default)]
struct TLSConfigResolved {
    identity: Option<tonic::transport::Identity>,
    ca_certificate: Option<tonic::transport::Certificate>,
}

impl TonicConnector {
    /// All URLs support adding `wait-connect=1` as a URL parameter, in which case
    /// the connection is established lazily.
    pub fn from_url(url: &url::Url) -> Result<TonicConnector, self::Error> {
        let url_params = url
            .query()
            .map(serde_qs::from_str::<URLParams>)
            .transpose()?
            .unwrap_or_default();

        let tls_config_params = url
            .query()
            .map(serde_qs::from_str::<TLSConfigParams>)
            .transpose()?
            .unwrap_or_default();
        if url.scheme() != "grpc+https" && tls_config_params != TLSConfigParams::default() {
            return Err(Error::TLSConfigOnPlain);
        }

        match url.scheme() {
            "grpc+unix" => {
                if url.has_authority() {
                    return Err(Error::AuthorityDisallowed());
                }

                Ok(Self {
                    transport: Transport::UnixDomainSocket {
                        path: url.path().into(),
                    },
                    url_params,
                })
            }
            "grpc+http" | "grpc+https" => {
                // ensure path is empty, not supported with gRPC.
                if !url.path().is_empty() {
                    return Err(Error::PathMayNotBeSet());
                }

                // Stringify the URL and remove the grpc+ prefix.
                // We can't use `url.set_scheme(rest)`, as it disallows
                // setting something http(s) that previously wasn't.
                let unprefixed_url = url
                    .as_str()
                    .strip_prefix("grpc+")
                    .expect("grpc+ is prefix")
                    .to_string();

                Ok(Self {
                    transport: Transport::HTTP2 {
                        url: unprefixed_url,
                        tls_config_params: (url.scheme() == "grpc+https")
                            .then_some(tls_config_params),
                    },
                    url_params,
                })
            }
            scheme => Err(Error::UnsupportedScheme(scheme.to_owned())),
        }
    }

    // Tries to connect lazily
    // Will panic if `wait-connect=1` was set in the URL, as connecting
    // non-lazily needs to be async, use [Self::connect] for that.
    pub async fn connect(self) -> Result<Channel, Error> {
        match self.transport {
            Transport::HTTP2 {
                url,
                tls_config_params: None,
            } => {
                let endpoint = setup_endpoint_http(url, None)?;

                Ok(if self.url_params.wait_connect {
                    endpoint.connect().await?
                } else {
                    endpoint.connect_lazy()
                })
            }
            Transport::HTTP2 {
                url,
                tls_config_params: Some(tls_config_params),
            } => {
                let endpoint =
                    setup_endpoint_http(url, Some(resolve_tls_config(tls_config_params).await?))?;

                Ok(if self.url_params.wait_connect {
                    endpoint.connect().await?
                } else {
                    endpoint.connect_lazy()
                })
            }
            Transport::UnixDomainSocket { path } => {
                let connector = tower::service_fn(move |_| {
                    let unix = UnixStream::connect(path.clone());
                    async move { Ok::<_, std::io::Error>(TokioIo::new(unix.await?)) }
                });

                let endpoint = Endpoint::from_static("http://[::]:50051");
                Ok(if self.url_params.wait_connect {
                    endpoint.connect_with_connector(connector).await?
                } else {
                    endpoint.connect_with_connector_lazy(connector)
                })
            }
        }
    }

    // Tries to connect lazily
    // Will panic if `wait-connect=1` was set in the URL, as connecting
    // non-lazily needs to be async, use [Self::connect] for that.
    pub fn connect_expect_lazy(self) -> Channel {
        assert!(
            !self.url_params.wait_connect,
            "wait-connect URL called with connect_lazy"
        );

        match self.transport {
            Transport::HTTP2 {
                url,
                tls_config_params,
            } => {
                if tls_config_params == Some(TLSConfigParams::default())
                    || tls_config_params.is_none()
                {
                    let endpoint = setup_endpoint_http(
                        url,
                        tls_config_params.map(|_| TLSConfigResolved::default()),
                    )
                    .expect("to not fail");

                    endpoint.connect_lazy()
                } else {
                    // NOTE: we cannot reach this code right now, as the only user
                    // of `connect_expect_lazy` (`NixHTTPPathInfoService`) does not yet support any
                    // TLS config.
                    todo!("implement me");
                }
            }
            Transport::UnixDomainSocket { path } => {
                let connector = tower::service_fn(move |_| {
                    let unix = UnixStream::connect(path.clone());
                    async move { Ok::<_, std::io::Error>(TokioIo::new(unix.await?)) }
                });

                let endpoint = Endpoint::from_static("http://[::]:50051");

                endpoint.connect_with_connector_lazy(connector)
            }
        }
    }
}

/// Takes a [TLSConfigParams], and returns a [TLSConfigResolved].
/// Going from one to the other potentially requires doing IO, so this function
/// is async.
async fn resolve_tls_config(
    tls_config_params: TLSConfigParams,
) -> Result<TLSConfigResolved, Error> {
    let identity = match (
        tls_config_params.tls_client_cert_path,
        tls_config_params.tls_client_key_path,
    ) {
        (Some(p_cert), Some(p_key)) => {
            let cert_pem = tokio::fs::read_to_string(&p_cert)
                .await
                .map_err(|err| Error::ReadingFile("tls_client_cert_path", p_cert, err))?;
            let key_pem = tokio::fs::read_to_string(&p_key)
                .await
                .map_err(|err| Error::ReadingFile("tls_client_key_path", p_key, err))?;

            Some(tonic::transport::Identity::from_pem(cert_pem, key_pem))
        }
        (None, None) => None,
        _ => return Err(Error::TLSIdentityPartial),
    };

    let ca_certificate = if let Some(p) = tls_config_params.tls_ca_cert_path {
        let ca_cert_pem = tokio::fs::read_to_string(&p)
            .await
            .map_err(|err| Error::ReadingFile("tls_ca_cert_path", p, err))?;

        Some(tonic::transport::Certificate::from_pem(ca_cert_pem))
    } else {
        None
    };

    Ok(TLSConfigResolved {
        identity,
        ca_certificate,
    })
}

/// Helper function configuring [Endpoint] from a url and `Option<TLSConfigResolved>`.
/// Factored out to be used from both [TonicConnector::connect] and
/// [TonicConnector::connect_expect_lazy].
fn setup_endpoint_http(
    url: String,
    tls_config_params: Option<TLSConfigResolved>,
) -> Result<Endpoint, Error> {
    let mut endpoint = Endpoint::from_shared(url)?;

    if let Some(tls_config_params) = tls_config_params {
        let mut client_tls_config = tonic::transport::ClientTlsConfig::new();

        if let Some(ca_cert) = tls_config_params.ca_certificate {
            client_tls_config = client_tls_config.ca_certificates([ca_cert])
        } else {
            client_tls_config = client_tls_config.with_enabled_roots()
        };

        if let Some(identity) = tls_config_params.identity {
            client_tls_config = client_tls_config.identity(identity)
        }

        endpoint = endpoint.tls_config(client_tls_config)?;
    }

    Ok(endpoint)
}

/// Turn a [url::Url] to a [Channel] if it can be parsed successfully.
/// It supports the following schemes (and URLs):
///  - `grpc+http://[::1]:8000`, connecting over unencrypted HTTP/2 (h2c)
///  - `grpc+https://[::1]:8000`, connecting over encrypted HTTP/2
///  - `grpc+unix:/path/to/socket`, connecting to a unix domain socket
pub async fn channel_from_url(url: &url::Url) -> Result<Channel, Error> {
    TonicConnector::from_url(url)?.connect().await
}

/// Errors occuring when parsing a gRPC backend URL, or trying to connect to it.
#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("Unsupported gRPC scheme: {0}")]
    UnsupportedScheme(String),

    #[error("unix domain sockets URLs should not have authority")]
    AuthorityDisallowed(),

    #[error("path may not be set")]
    PathMayNotBeSet(),

    #[error("parsing query string")]
    ParsingQS(#[from] serde_qs::Error),

    #[error("reading {0} at {1}: {2}")]
    ReadingFile(&'static str, PathBuf, std::io::Error),

    #[error("transport error: {0}")]
    TransportError(tonic::transport::Error),

    #[error("unexpected TLS config on non-TLS URL")]
    TLSConfigOnPlain,

    #[error("Only one of TLS Identity key and cert specified")]
    TLSIdentityPartial,
}

impl From<tonic::transport::Error> for Error {
    fn from(value: tonic::transport::Error) -> Self {
        Self::TransportError(value)
    }
}

#[cfg(test)]
mod tests {
    use super::{TonicConnector, channel_from_url};
    use rstest::rstest;
    use url::Url;

    #[rstest]
    /// Correct scheme to connect to a unix socket.
    #[case::valid_unix_socket("grpc+unix:/path/to/somewhere", true)]
    /// Connecting with wait-connect set to 0 succeeds, as that's the default.
    #[case::valid_unix_socket_wait_connect_0("grpc+unix:/path/to/somewhere?wait-connect=0", true)]
    /// Connecting with wait-connect set to 1 fails, as the path doesn't exist.
    #[case::valid_unix_socket_wait_connect_1("grpc+unix:/path/to/somewhere?wait-connect=1", false)]
    /// Correct scheme for unix socket, but setting authority, which is invalid.
    #[case::invalid_unix_socket_with_authority("grpc+unix:///path/to/somewhere", false)]
    /// Correct scheme for unix socket, but setting a host too, which is invalid.
    #[case::invalid_unix_socket_and_host("grpc+unix://host.example/path/to/somewhere", false)]
    /// Correct scheme to connect to localhost, with port 12345
    #[case::valid_ipv6_localhost_port_12345("grpc+http://[::1]:12345", true)]
    /// Correct scheme to connect to localhost over http, without specifying a port.
    #[case::valid_http_host_without_port("grpc+http://localhost", true)]
    /// Correct scheme to connect to localhost over http, without specifying a port.
    #[case::valid_https_host_without_port("grpc+https://localhost", true)]
    /// Correct scheme to connect to localhost over http, but with additional path, which is invalid.
    #[case::invalid_host_and_path("grpc+http://localhost/some-path", false)]
    /// Connecting with wait-connect set to 0 succeeds, as that's the default.
    #[case::valid_host_wait_connect_0("grpc+http://localhost?wait-connect=0", true)]
    /// Connecting with wait-connect set to 1 fails, as the host doesn't exist.
    #[case::valid_host_wait_connect_1_fails("grpc+http://nonexist.invalid?wait-connect=1", false)]
    #[tokio::test]
    async fn test_channel_from_url_tokio(#[case] uri_str: &str, #[case] is_ok: bool) {
        use pretty_assertions::assert_matches;
        let url = Url::parse(uri_str).expect("must parse");

        if is_ok {
            assert_matches!(channel_from_url(&url).await, Ok(_))
        } else {
            assert_matches!(channel_from_url(&url).await, Err(_))
        }
    }

    #[rstest]
    /// A bunch of tests testing (m)TLS-related URLs.
    /// We test from_url directly, as the connect() part, even in the lazy default case
    /// will read keys from disk not only when doing the first request, but during the function call.
    #[case::valid_mtls_custom_cacert("grpc+https://localhost?tls-ca-cert-path=/dev/null", true)]
    #[case::valid_mtls(
        "grpc+https://localhost?tls-client-cert-path=/dev/null&tls-client-key-path=/dev/null",
        true
    )]
    #[case::valid_mtls_custom_cacert(
        "grpc+https://localhost?tls-client-cert-path=/dev/null&tls-client-key-path=/dev/null&tls-ca-cert-path=/dev/null",
        true
    )]
    #[tokio::test]
    async fn test_from_url(#[case] uri_str: &str, #[case] is_ok: bool) {
        use pretty_assertions::assert_matches;
        let url = Url::parse(uri_str).expect("must parse");

        let result = TonicConnector::from_url(&url);

        if is_ok {
            assert_matches!(result, Ok(_))
        } else {
            assert_matches!(result, Err(_))
        }
    }
}
