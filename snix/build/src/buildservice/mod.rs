use auto_impl::auto_impl;
use tonic::async_trait;

pub mod build_request;
pub use crate::buildservice::build_request::*;
mod dummy;
mod from_addr;
mod grpc;

#[cfg(target_os = "linux")]
mod oci;

#[cfg(target_os = "linux")]
mod bwrap;

pub use dummy::DummyBuildService;
pub use from_addr::from_addr;

#[async_trait]
#[auto_impl(&, &mut, Arc, Box)]
pub trait BuildService: Send + Sync {
    /// TODO: document
    async fn do_build(&self, request: BuildRequest) -> std::io::Result<BuildResult>;
}
