use clap::Parser;
use snix_castore::Node;

use snix_castore::{B3Digest, utils::ServiceUrlsGrpc};

#[derive(Parser)]
#[command(author, version, about)]
struct Args {
    /// The address to listen on.
    #[clap(flatten)]
    listen_args: tokio_listener::ListenerAddressLFlag,
    #[clap(flatten)]
    service_addrs: ServiceUrlsGrpc,
    /// The root directory digest to serve.
    #[arg(short, long)]
    root_directory: B3Digest,
    /// The name of the file to serve if a client requests a directory, seperated by ','. e.g. "index.html,index.htm"
    #[arg(long, value_delimiter = ',')]
    index_names: Vec<String>,
    /// Whether a directory listing should be returned if a client requests a directory but none of the `index_names` matched
    #[arg(short, long)]
    auto_index: bool,

    #[clap(flatten)]
    tracing_args: snix_tracing::TracingArgs,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = Args::parse();

    let _tracing_handle = snix_tracing::TracingBuilder::default()
        .handle_tracing_args(&args.tracing_args)
        .enable_progressbar()
        .build()?;

    snix_castore_http::router::gen_router(
        args.listen_args,
        args.service_addrs,
        Node::Directory {
            digest: args.root_directory,
            // size doesn't really matter here, we're not doing inode allocation.
            size: 0,
        },
        &args.index_names,
        args.auto_index,
    )
    .await
}
