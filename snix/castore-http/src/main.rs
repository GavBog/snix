use clap::Parser;
use snix_castore::Node;
use snix_castore_http::cli::CliArgs;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt().init();

    let args: CliArgs = snix_castore_http::cli::CliArgs::parse();

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
