use std::sync::Arc;

use tokio::io::AsyncRead;
use tonic::async_trait;
use tracing::instrument;

use crate::B3Digest;
use crate::composition::{CompositionContext, ServiceBuilder};

use super::{BlobReader, BlobService, BlobWriter, ChunkedReader};

/// Cache for a BlobService, using a "near" and "far" blobservice.
/// Requests are tried in (and returned from) the near store first, only if
/// things are not present there, the far BlobService is queried.
/// In case the near blobservice doesn't have the blob, we ask the remote
/// blobservice for chunks, and try to read each of these chunks from the near
/// blobservice again, before falling back to the far one.
/// While doing so, the full blob is written to the near blobservice.
/// The far BlobService is never written to.
#[derive(Clone)]
pub struct Cache<BN, BF>
where
    BN: Clone,
    BF: Clone,
{
    instance_name: String,
    near: BN,
    far: BF,
}

impl<BN, BF> Cache<BN, BF>
where
    BN: Clone,
    BF: Clone,
{
    pub fn new(instance_name: String, near: BN, far: BF) -> Self {
        Self {
            instance_name,
            near,
            far,
        }
    }
}

#[async_trait]
impl<BN, BF> BlobService for Cache<BN, BF>
where
    BN: BlobService + Clone + 'static,
    BF: BlobService + Clone + 'static,
{
    #[instrument(skip(self, digest), fields(blob.digest=%digest, instance_name=%self.instance_name))]
    async fn has(&self, digest: &B3Digest) -> std::io::Result<bool> {
        Ok(self.near.has(digest).await? || self.far.has(digest).await?)
    }

    #[instrument(skip(self, digest), fields(blob.digest=%digest, instance_name=%self.instance_name), err)]
    async fn open_read(&self, digest: &B3Digest) -> std::io::Result<Option<Box<dyn BlobReader>>> {
        if self.near.has(digest).await? {
            // near store has the blob, so we can assume it also has all chunks.
            self.near.open_read(digest).await
        } else {
            // near store doesn't have the blob.
            // Ask the remote one for the list of chunks,
            // and create a chunked reader that uses self.open_read() for
            // individual chunks. There's a chance we already have some chunks
            // in near, meaning we don't need to fetch them all from the far
            // BlobService.
            match self.far.chunks(digest).await? {
                // blob doesn't exist on the far side either, nothing we can do.
                None => Ok(None),
                Some(remote_chunks) => {
                    let mut far_reader = {
                        // if there's no more granular chunks, or the far
                        // blobservice doesn't support chunks, read the blob from
                        // the far blobservice directly.
                        if remote_chunks.is_empty() {
                            if let Some(reader) = self.far.open_read(digest).await? {
                                Box::new(reader) as Box<dyn AsyncRead + Unpin + Send>
                            } else {
                                return Ok(None);
                            }
                        } else {
                            // otherwise, a chunked reader, which will always try the
                            // near backend first.
                            Box::new(ChunkedReader::from_chunks(
                                remote_chunks.into_iter().map(|chunk| {
                                    (
                                        chunk.digest.try_into().expect("invalid b3 digest"),
                                        chunk.size,
                                    )
                                }),
                                Arc::new(self.clone()) as Arc<dyn BlobService>,
                            )) as Box<dyn AsyncRead + Unpin + Send>
                        }
                    };

                    // Blob is present on the remote blobservice.
                    // Copy it into the near blobservice, then return from there.
                    let mut near_blobwriter = self.near.open_write().await;
                    tokio::io::copy(&mut far_reader, &mut near_blobwriter).await?;

                    let written_digest = near_blobwriter.close().await?;
                    if written_digest != *digest {
                        return Err(std::io::Error::other(
                            "blob written to near blobservice returned unexpected digest",
                        ));
                    }

                    return self.near.open_read(digest).await;
                }
            }
        }
    }

    #[instrument(skip_all, fields(instance_name=%self.instance_name))]
    async fn open_write(&self) -> Box<dyn BlobWriter> {
        // direct writes to the near one.
        self.near.open_write().await
    }
}

#[derive(serde::Deserialize, Debug, Clone)]
#[serde(deny_unknown_fields)]
pub struct CacheBlobServiceConfig {
    near: String,
    far: String,
}

impl TryFrom<url::Url> for CacheBlobServiceConfig {
    type Error = Box<dyn std::error::Error + Send + Sync>;
    fn try_from(_url: url::Url) -> Result<Self, Self::Error> {
        Err("Instantiating a CacheBlobService from a url is not supported".into())
    }
}

#[async_trait]
impl ServiceBuilder for CacheBlobServiceConfig {
    type Output = dyn BlobService;
    async fn build<'a>(
        &'a self,
        instance_name: &str,
        context: &CompositionContext,
    ) -> Result<Arc<Self::Output>, Box<dyn std::error::Error + Send + Sync>> {
        let (near, far) = futures::join!(
            context.resolve::<dyn BlobService>(&self.near),
            context.resolve::<dyn BlobService>(&self.far)
        );
        Ok(Arc::new(Cache {
            instance_name: instance_name.to_string(),
            near: near?,
            far: far?,
        }))
    }
}
