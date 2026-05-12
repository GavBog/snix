use tonic::async_trait;

use crate::buildservice::BuildRequest;
use crate::proto::{self, build_service_client::BuildServiceClient};

use super::{BuildResult, BuildService};

pub struct GRPCBuildService<T> {
    client: BuildServiceClient<T>,
}

impl<T> GRPCBuildService<T> {
    #[allow(dead_code)]
    pub fn from_client(client: BuildServiceClient<T>) -> Self {
        Self { client }
    }
}

#[async_trait]
impl<T> BuildService for GRPCBuildService<T>
where
    T: tonic::client::GrpcService<tonic::body::Body> + Send + Sync + Clone + 'static,
    T::ResponseBody: tonic::codegen::Body<Data = tonic::codegen::Bytes> + Send + 'static,
    <T::ResponseBody as tonic::codegen::Body>::Error: Into<tonic::codegen::StdError> + Send,
    T::Future: Send,
{
    async fn do_build(&self, request: BuildRequest) -> std::io::Result<BuildResult> {
        let mut client = self.client.clone();
        let resp = client
            .do_build(Into::<proto::BuildRequest>::into(request))
            .await
            .map_err(std::io::Error::other)?
            .into_inner();

        Ok::<BuildResult, _>(resp.try_into().map_err(std::io::Error::other)?)
    }
}
