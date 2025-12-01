use crate::directoryservice::{DirectoryService, LeavesToRootValidator};
use crate::{B3Digest, DirectoryError, proto};
use futures::TryStreamExt;
use futures::stream::BoxStream;
use std::ops::Deref;
use tokio_stream::once;
use tonic::{Request, Response, Status, Streaming, async_trait};
use tracing::{instrument, warn};

pub struct GRPCDirectoryServiceWrapper<T> {
    directory_service: T,
}

impl<T> GRPCDirectoryServiceWrapper<T> {
    pub fn new(directory_service: T) -> Self {
        Self { directory_service }
    }
}

#[async_trait]
impl<T> proto::directory_service_server::DirectoryService for GRPCDirectoryServiceWrapper<T>
where
    T: Deref<Target = dyn DirectoryService> + Send + Sync + 'static,
{
    type GetStream = BoxStream<'static, tonic::Result<proto::Directory, Status>>;

    #[instrument(skip_all)]
    async fn get<'a>(
        &'a self,
        request: Request<proto::GetDirectoryRequest>,
    ) -> Result<Response<Self::GetStream>, Status> {
        let req_inner = request.into_inner();

        let by_what = &req_inner
            .by_what
            .ok_or_else(|| Status::invalid_argument("invalid by_what"))?;

        match by_what {
            proto::get_directory_request::ByWhat::Digest(digest) => {
                let digest: B3Digest = digest
                    .clone()
                    .try_into()
                    .map_err(|_e| Status::invalid_argument("invalid digest length"))?;

                Ok(tonic::Response::new({
                    if !req_inner.recursive {
                        let directory = self
                            .directory_service
                            .get(&digest)
                            .await
                            .map_err(|e| {
                                warn!(err = %e, directory.digest=%digest, "failed to get directory");
                                tonic::Status::new(tonic::Code::Internal, e.to_string())
                            })?
                            .ok_or_else(|| {
                                Status::not_found(format!("directory {digest} not found"))
                            })?;

                        Box::pin(once(Ok(directory.into())))
                    } else {
                        // If recursive was requested, traverse via get_recursive.
                        Box::pin(
                            self.directory_service
                                .get_recursive(&digest)
                                .map_ok(proto::Directory::from)
                                .map_err(|e| {
                                    tonic::Status::new(tonic::Code::Internal, e.to_string())
                                }),
                        )
                    }
                }))
            }
        }
    }

    #[instrument(skip_all)]
    async fn put(
        &self,
        request: Request<Streaming<proto::Directory>>,
    ) -> Result<Response<proto::PutDirectoryResponse>, Status> {
        let mut req_inner = request.into_inner();

        // Validate all received directories.
        let mut validator = LeavesToRootValidator::new();

        // Insert into the backing DirectoryService as we receive.
        let mut directory_putter = self.directory_service.put_multiple_start();

        while let Some(directory) = req_inner.message().await? {
            let directory: crate::Directory =
                directory.try_into().map_err(|e: DirectoryError| {
                    tonic::Status::new(tonic::Code::Internal, e.to_string())
                })?;
            validator
                .try_accept(&directory)
                .map_err(|e| tonic::Status::new(tonic::Code::Internal, e.to_string()))?;

            directory_putter.put(directory).await?;
        }

        // Finalize validator, checks connectivity.
        validator
            .finalize()
            .map_err(|e| tonic::Status::new(tonic::Code::Internal, e.to_string()))?;

        Ok(Response::new(proto::PutDirectoryResponse {
            // Properly close the directory putter, returning any potential errors.
            root_digest: directory_putter.close().await?.into(),
        }))
    }
}
