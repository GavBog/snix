use std::collections::HashMap;
use std::collections::hash_map;
use std::sync::Arc;

use async_stream::try_stream;
use data_encoding::HEXLOWER;
use futures::SinkExt;
use futures::StreamExt;
use futures::TryFutureExt;
use futures::TryStreamExt;
use futures::future::Either;
use futures::stream::BoxStream;
use object_store::{ObjectStore, path::Path};
use prost::Message;
use tokio::io::AsyncWriteExt;
use tokio_util::codec::LengthDelimitedCodec;
use tonic::async_trait;
use tracing::{Level, instrument, trace, warn};
use url::Url;

use super::{Directory, DirectoryPutter, DirectoryService, RootToLeavesValidator};
use crate::composition::{CompositionContext, ServiceBuilder};
use crate::directoryservice::directory_graph::DirectoryGraphBuilder;
use crate::directoryservice::directory_graph::DirectoryOrder;
use crate::{B3Digest, Error, Node, proto};

/// Stores directory closures in an object store.
/// Notably, this makes use of the option to disallow accessing child directories except when
/// fetching them recursively via the top-level directory, since all batched writes
/// (using `put_multiple_start`) are stored in a single object.
/// Directories are stored in a length-delimited format with a 1MiB limit. The length field is a
/// u32 and the directories are stored in root-to-leaves topological order, the same way they will
/// be returned to the client in get_recursive.
#[derive(Clone)]
pub struct ObjectStoreDirectoryService {
    instance_name: String,
    object_store: Arc<dyn ObjectStore>,
    base_path: Path,
}

#[instrument(level=Level::TRACE, skip_all,fields(base_path=%base_path,blob.digest=%digest),ret(Display))]
fn derive_dirs_path(base_path: &Path, digest: &B3Digest) -> Path {
    base_path
        .child("dirs")
        .child("b3")
        .child(HEXLOWER.encode(&digest.as_slice()[..2]))
        .child(HEXLOWER.encode(digest.as_slice()))
}

/// Helper function, parsing protobuf-encoded Directories into [crate::Directory],
/// if the digest is allowed.
fn parse_proto_directory<F>(
    encoded_directory: &[u8],
    digest_allowed: F,
) -> Result<crate::Directory, Error>
where
    F: Fn(&B3Digest) -> bool,
{
    let actual_digest = B3Digest::from(blake3::hash(encoded_directory).as_bytes());
    if !digest_allowed(&actual_digest) {
        return Err(crate::Error::StorageError(
            "unexpected directory digest".to_string(),
        ));
    }

    let directory_proto = proto::Directory::decode(encoded_directory).map_err(|e| {
        warn!("unable to parse directory {}: {}", actual_digest, e);
        Error::StorageError(e.to_string())
    })?;

    Directory::try_from(directory_proto).map_err(|e| {
        warn!("unable to convert directory {}: {}", actual_digest, e);
        Error::StorageError(e.to_string())
    })
}

#[allow(clippy::identity_op)]
const MAX_FRAME_LENGTH: usize = 1 * 1024 * 1024 * 1000; // 1 MiB
//
impl ObjectStoreDirectoryService {
    /// Constructs a new [ObjectStoreDirectoryService] from a [Url] supported by
    /// [object_store].
    /// Any path suffix becomes the base path of the object store.
    /// additional options, the same as in [object_store::parse_url_opts] can
    /// be passed.
    pub fn parse_url_opts<I, K, V>(url: &Url, options: I) -> Result<Self, object_store::Error>
    where
        I: IntoIterator<Item = (K, V)>,
        K: AsRef<str>,
        V: Into<String>,
    {
        let (object_store, path) = object_store::parse_url_opts(url, options)?;

        Ok(Self {
            instance_name: "root".into(),
            object_store: Arc::new(object_store),
            base_path: path,
        })
    }

    /// Like [Self::parse_url_opts], except without the options.
    pub fn parse_url(url: &Url) -> Result<Self, object_store::Error> {
        Self::parse_url_opts(url, Vec::<(String, String)>::new())
    }

    pub fn new(instance_name: String, object_store: Arc<dyn ObjectStore>, base_path: Path) -> Self {
        Self {
            instance_name,
            object_store,
            base_path,
        }
    }
}

#[async_trait]
impl DirectoryService for ObjectStoreDirectoryService {
    /// This is the same steps as for get_recursive anyways, so we just call get_recursive and
    /// return the first element of the stream and drop the request.
    #[instrument(level = "trace", skip_all, fields(directory.digest = %digest, instance_name = %self.instance_name))]
    async fn get(&self, digest: &B3Digest) -> Result<Option<Directory>, Error> {
        self.get_recursive(digest).take(1).next().await.transpose()
    }

    #[instrument(level = "trace", skip_all, fields(directory.digest = %directory.digest(), instance_name = %self.instance_name))]
    async fn put(&self, directory: Directory) -> Result<B3Digest, Error> {
        // Ensure the directory doesn't contain other directory children
        if directory
            .nodes()
            .any(|(_, e)| matches!(e, Node::Directory { .. }))
        {
            return Err(Error::InvalidRequest(
                    "only put_multiple_start is supported by the ObjectStoreDirectoryService for directories with children".into(),
            ));
        }

        let mut handle = self.put_multiple_start();
        handle.put(directory).await?;
        handle.close().await
    }

    #[instrument(level = "trace", skip_all, fields(directory.digest = %root_directory_digest, instance_name = %self.instance_name))]
    fn get_recursive(
        &self,
        root_directory_digest: &B3Digest,
    ) -> BoxStream<'static, Result<Directory, Error>> {
        // Check that we are not passing on bogus from the object store to the client, and that the
        // trust chain from the root digest to the leaves is intact.
        let dir_path = derive_dirs_path(&self.base_path, root_directory_digest);
        let object_store = self.object_store.clone();
        let root_directory_digest = root_directory_digest.to_owned();

        Box::pin(
            (async move {
                let stream = match object_store.get(&dir_path).await {
                    Ok(v) => v.into_stream(),
                    Err(object_store::Error::NotFound { .. }) => {
                        return Ok(Either::Left(futures::stream::empty()));
                    }
                    Err(e) => return Err(std::io::Error::from(e).into()),
                };

                // get a reader of the response body.
                let r = tokio_util::io::StreamReader::new(stream);
                let decompressed_stream = async_compression::tokio::bufread::ZstdDecoder::new(r);

                // the subdirectories are stored in a length delimited format
                let mut encoded_directories = LengthDelimitedCodec::builder()
                    .max_frame_length(MAX_FRAME_LENGTH)
                    .length_field_type::<u32>()
                    .new_read(decompressed_stream)
                    .err_into::<Error>();

                Ok(Either::Right(try_stream! {
                    let mut order_validator = if let Some(encoded_directory) = encoded_directories.try_next().await? {
                        let directory = parse_proto_directory(&encoded_directory, |digest| {
                            digest == &root_directory_digest
                        })?;

                        let order_validator = RootToLeavesValidator::new_with_root(&directory);
                        yield directory;
                        order_validator
                    } else {
                        // no elements in stream
                        Err(Error::StorageError("no directories stored".to_string()))?
                    };

                    while let Some(encoded_directory) = encoded_directories.try_next().await? {
                        let directory = parse_proto_directory(&encoded_directory, |digest| {
                            order_validator.would_accept(digest)
                        })?;

                        order_validator.try_accept(&directory).map_err(|e| Error::StorageError(e.to_string()))?;

                        yield directory;
                    }

                    order_validator.finalize().map_err(|e| Error::StorageError(e.to_string()))?;
                }))
            })
            .try_flatten_stream(),
        )
    }

    #[instrument(skip_all)]
    fn put_multiple_start(&self) -> Box<dyn DirectoryPutter + '_>
    where
        Self: Clone,
    {
        Box::new(ObjectStoreDirectoryPutter::new(
            self.object_store.clone(),
            &self.base_path,
        ))
    }
}

#[derive(serde::Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ObjectStoreDirectoryServiceConfig {
    object_store_url: String,
    #[serde(default)]
    object_store_options: HashMap<String, String>,
}

impl TryFrom<url::Url> for ObjectStoreDirectoryServiceConfig {
    type Error = Box<dyn std::error::Error + Send + Sync>;
    fn try_from(url: url::Url) -> Result<Self, Self::Error> {
        // We need to convert the URL to string, strip the prefix there, and then
        // parse it back as url, as Url::set_scheme() rejects some of the transitions we want to do.
        let trimmed_url = {
            let s = url.to_string();
            let mut url = Url::parse(
                s.strip_prefix("objectstore+")
                    .ok_or(Error::StorageError("Missing objectstore uri".into()))?,
            )?;
            // trim the query pairs, they might contain credentials or local settings we don't want to send as-is.
            url.set_query(None);
            url
        };
        Ok(ObjectStoreDirectoryServiceConfig {
            object_store_url: trimmed_url.into(),
            object_store_options: url
                .query_pairs()
                .into_iter()
                .map(|(k, v)| (k.to_string(), v.to_string()))
                .collect(),
        })
    }
}

#[async_trait]
impl ServiceBuilder for ObjectStoreDirectoryServiceConfig {
    type Output = dyn DirectoryService;
    async fn build<'a>(
        &'a self,
        instance_name: &str,
        _context: &CompositionContext,
    ) -> Result<Arc<dyn DirectoryService>, Box<dyn std::error::Error + Send + Sync + 'static>> {
        let opts = {
            let mut opts: HashMap<&str, _> = self
                .object_store_options
                .iter()
                .map(|(k, v)| (k.as_str(), v.as_str()))
                .collect();

            if let hash_map::Entry::Vacant(e) =
                opts.entry(object_store::ClientConfigKey::UserAgent.as_ref())
            {
                e.insert(crate::USER_AGENT);
            }

            opts
        };

        let (object_store, path) =
            object_store::parse_url_opts(&self.object_store_url.parse()?, opts)?;
        Ok(Arc::new(ObjectStoreDirectoryService::new(
            instance_name.to_string(),
            Arc::new(object_store),
            path,
        )))
    }
}

struct ObjectStoreDirectoryPutter<'a> {
    object_store: Arc<dyn ObjectStore>,
    base_path: &'a Path,

    builder: Option<DirectoryGraphBuilder>,
}

impl<'a> ObjectStoreDirectoryPutter<'a> {
    fn new(object_store: Arc<dyn ObjectStore>, base_path: &'a Path) -> Self {
        Self {
            object_store,
            base_path,
            builder: Some(DirectoryGraphBuilder::new_leaves_to_root()),
        }
    }
}

#[async_trait]
impl DirectoryPutter for ObjectStoreDirectoryPutter<'_> {
    #[instrument(level = "trace", skip_all, fields(directory.digest=%directory.digest()), err)]
    async fn put(&mut self, directory: Directory) -> Result<(), Error> {
        let builder = self
            .builder
            .as_mut()
            .ok_or_else(|| Error::StorageError("already closed".to_string()))?;

        builder.try_insert(directory)?;

        Ok(())
    }

    #[instrument(level = "trace", skip_all, ret, err)]
    async fn close(&mut self) -> Result<B3Digest, Error> {
        let builder = self
            .builder
            .take()
            .ok_or_else(|| Error::StorageError("already closed".to_string()))?;

        // Retrieve the validated directories.
        let directory_graph = builder.build()?;
        let root_digest = directory_graph.root().digest();

        let dir_path = derive_dirs_path(self.base_path, &root_digest);

        match self.object_store.head(&dir_path).await {
            // directory tree already exists, nothing to do
            Ok(_) => {
                trace!("directory tree already exists");
            }

            // directory tree does not yet exist, compress and upload.
            Err(object_store::Error::NotFound { .. }) => {
                trace!("uploading directory tree");

                let object_store_writer =
                    object_store::buffered::BufWriter::new(self.object_store.clone(), dir_path);
                let compressed_writer =
                    async_compression::tokio::write::ZstdEncoder::new(object_store_writer);
                let mut directories_sink = LengthDelimitedCodec::builder()
                    .max_frame_length(MAX_FRAME_LENGTH)
                    .length_field_type::<u32>()
                    .new_write(compressed_writer);

                for directory in directory_graph.drain(DirectoryOrder::RootToLeaves) {
                    directories_sink
                        .send(proto::Directory::from(directory).encode_to_vec().into())
                        .await?;
                }

                let mut compressed_writer = directories_sink.into_inner();
                compressed_writer.shutdown().await?;
            }
            // other error
            Err(err) => Err(std::io::Error::from(err))?,
        }

        Ok(root_digest)
    }
}
