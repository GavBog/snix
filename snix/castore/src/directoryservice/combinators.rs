use std::sync::Arc;

use futures::StreamExt;
use futures::TryStreamExt;
use futures::stream::BoxStream;
use tonic::async_trait;
use tracing::{instrument, trace};

use super::{Directory, DirectoryService, SimplePutter};
use crate::B3Digest;
use crate::Error;
use crate::composition::{CompositionContext, ServiceBuilder};
use crate::directoryservice::DirectoryPutter;
use crate::directoryservice::directory_graph::DirectoryGraphBuilder;

/// Asks near first, if not found, asks far.
/// If found in there, returns it, and *inserts* it into
/// near.
/// Specifically, it always obtains the entire directory closure from far and inserts it into near,
/// which is useful when far does not support accessing intermediate directories (but near does).
/// There is no negative cache.
/// Inserts and listings are not implemented for now.
pub struct Cache<DS1, DS2> {
    instance_name: String,
    near: DS1,
    far: DS2,
}

impl<DS1, DS2> Cache<DS1, DS2> {
    pub fn new(instance_name: String, near: DS1, far: DS2) -> Self {
        Self {
            instance_name,
            near,
            far,
        }
    }
}

#[async_trait]
impl<DS1, DS2> DirectoryService for Cache<DS1, DS2>
where
    DS1: DirectoryService + Clone + 'static,
    DS2: DirectoryService + Clone + 'static,
{
    #[instrument(skip(self, digest), fields(directory.digest = %digest, instance_name = %self.instance_name))]
    async fn get(&self, digest: &B3Digest) -> Result<Option<Directory>, Error> {
        // check near
        if let Some(directory) = self.near.get(digest).await? {
            trace!("serving from cache");
            return Ok(Some(directory));
        }

        trace!("not found in near, asking remote…");
        // We always ask recursive, and populate the children to support far not allowing non-root access
        // We currently wait for all children to be received before returning
        // the requested directory, so subsequent children requests don't fail when these
        // stores are used.
        // FUTUREWORK: make this configurable, allow firing off a background task populating the children.
        let mut directories = self.far.get_recursive(digest);
        let mut graph_builder = DirectoryGraphBuilder::new_root_to_leaves(*digest);

        let mut resp_directory = None;
        while let Some(directory) = directories.try_next().await? {
            graph_builder.try_insert(directory.clone())?;
            if resp_directory.is_none() {
                resp_directory = Some(directory);
            }
        }

        // If far had the directory, put into near.
        if let Some(resp_directory) = resp_directory {
            let directory_graph = graph_builder.build()?;
            // Drain into near
            let mut near_putter = self.near.put_multiple_start();
            for directory in directory_graph.drain_leaves_to_root() {
                near_putter.put(directory).await?;
            }

            let actual_digest = near_putter.close().await?;
            debug_assert_eq!(digest, &actual_digest);
            Ok(Some(resp_directory))
        } else {
            Ok(None)
        }
    }

    #[instrument(skip_all, fields(instance_name = %self.instance_name))]
    async fn put(&self, _directory: Directory) -> Result<B3Digest, Error> {
        Err(Error::StorageError("unimplemented".to_string()))
    }

    #[instrument(skip_all, fields(directory.digest = %root_directory_digest, instance_name = %self.instance_name))]
    fn get_recursive(
        &self,
        root_directory_digest: &B3Digest,
    ) -> BoxStream<'_, Result<Directory, Error>> {
        let near = &self.near;
        let far = &self.far;
        let digest = *root_directory_digest;

        async_stream::try_stream! {
            let mut directories = near.get_recursive(&digest);

            if let Some(first) = directories.try_next().await? {
                trace!("serving from cache");
                yield first;

                while let Some(dir) = directories.try_next().await? {
                    yield dir;
                }
                return;
            }

            trace!("not found in near, asking remote…");

            let mut directories = far.get_recursive(&digest);
            let mut builder = DirectoryGraphBuilder::new_root_to_leaves(digest);

            // Return to the client, while inserting to the graph builder.
            while let Some(directory) = directories.try_next().await? {
                builder.try_insert(directory.clone())?;
                yield directory;
            }

            match builder.build() {
                Ok(directory_graph) => {
                    // Drain into near
                    let mut near_putter = near.put_multiple_start();
                    for directory in directory_graph.drain_leaves_to_root() {
                        near_putter.put(directory).await?;
                    }
                    let actual_digest = near_putter.close().await?;
                    debug_assert_eq!(digest, actual_digest);
                }
                Err(crate::directoryservice::OrderingError::EmptySet) => return,
                Err(e) => Err(e)?
            }
        }
        .boxed()
    }

    #[instrument(skip_all)]
    fn put_multiple_start(&self) -> Box<dyn DirectoryPutter + '_> {
        Box::new(SimplePutter::new(self))
    }
}

#[derive(serde::Deserialize, Debug)]
#[serde(deny_unknown_fields)]
pub struct CacheConfig {
    near: String,
    far: String,
}

impl TryFrom<url::Url> for CacheConfig {
    type Error = Box<dyn std::error::Error + Send + Sync>;
    fn try_from(url: url::Url) -> Result<Self, Self::Error> {
        // cache doesn't support host or path in the URL.
        if url.has_host() || !url.path().is_empty() {
            return Err(Error::StorageError("invalid url".to_string()).into());
        }
        Ok(serde_qs::from_str(url.query().unwrap_or_default())?)
    }
}

#[async_trait]
impl ServiceBuilder for CacheConfig {
    type Output = dyn DirectoryService;
    async fn build<'a>(
        &'a self,
        instance_name: &str,
        context: &CompositionContext,
    ) -> Result<Arc<dyn DirectoryService>, Box<dyn std::error::Error + Send + Sync + 'static>> {
        let (near, far) = futures::join!(
            context.resolve::<Self::Output>(&self.near),
            context.resolve::<Self::Output>(&self.far)
        );
        Ok(Arc::new(Cache {
            instance_name: instance_name.to_string(),
            near: near?,
            far: far?,
        }))
    }
}
