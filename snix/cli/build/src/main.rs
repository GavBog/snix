use clap::Parser;
use clap::Subcommand;
use snix_build::{
    buildservice,
    proto::{GRPCBuildServiceWrapper, build_service_server::BuildServiceServer},
};
use tokio_listener::Listener;
use tokio_listener::SystemOptions;
use tokio_listener::UserOptions;
use tonic::{self, transport::Server};
use tracing::info;

#[cfg(feature = "tonic-reflection")]
use snix_build::proto::FILE_DESCRIPTOR_SET;
#[cfg(feature = "tonic-reflection")]
use snix_castore::proto::FILE_DESCRIPTOR_SET as CASTORE_FILE_DESCRIPTOR_SET;

use mimalloc::MiMalloc;

#[global_allocator]
static GLOBAL: MiMalloc = MiMalloc;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    #[clap(flatten)]
    tracing_args: snix_tracing::TracingArgs,
}
#[derive(Subcommand)]
enum Commands {
    /// Runs the snix-build daemon.
    Daemon {
        #[arg(long, short = 'l')]
        listen_address: Option<String>,

        #[clap(flatten)]
        castore_service_addrs: snix_castore::utils::ServiceUrlsGrpc,

        #[arg(long, env, default_value = "dummy:")]
        build_service_addr: String,
    },
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let args = Cli::parse();

    let _tracing_handle = snix_tracing::TracingBuilder::default()
        .handle_tracing_args(&args.tracing_args)
        .build()?;

    match args.command {
        Commands::Daemon {
            listen_address,
            castore_service_addrs,
            build_service_addr,
        } => {
            let (blob_service, directory_service) =
                snix_castore::utils::construct_services(castore_service_addrs).await?;

            let build_service =
                buildservice::from_addr(&build_service_addr, blob_service, directory_service)
                    .await?;

            let listen_address = listen_address
                .unwrap_or_else(|| "[::]:8000".to_string())
                .parse()
                .unwrap();

            let mut server = Server::builder();

            #[allow(unused_mut)]
            let mut router = server.add_service(BuildServiceServer::new(
                GRPCBuildServiceWrapper::new(build_service),
            ));

            #[cfg(feature = "tonic-reflection")]
            {
                router = router.add_service(
                    tonic_reflection::server::Builder::configure()
                        .register_encoded_file_descriptor_set(CASTORE_FILE_DESCRIPTOR_SET)
                        .register_encoded_file_descriptor_set(FILE_DESCRIPTOR_SET)
                        .build_v1alpha()?,
                );
                router = router.add_service(
                    tonic_reflection::server::Builder::configure()
                        .register_encoded_file_descriptor_set(CASTORE_FILE_DESCRIPTOR_SET)
                        .register_encoded_file_descriptor_set(FILE_DESCRIPTOR_SET)
                        .build_v1()?,
                );
            }

            info!(listen_address=%listen_address, "listening");

            let listener = Listener::bind(
                &listen_address,
                &SystemOptions::default(),
                &UserOptions::default(),
            )
            .await?;

            router.serve_with_incoming(listener).await?;
        }
    }

    Ok(())
}
