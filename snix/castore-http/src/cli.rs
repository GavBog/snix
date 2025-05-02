use clap::Parser;
use snix_castore::{B3Digest, utils::ServiceUrlsGrpc};

#[derive(Parser)]
#[command(author, version, about)]
pub struct CliArgs {
    /// The address to listen on
    #[clap(flatten)]
    pub listen_args: tokio_listener::ListenerAddressLFlag,
    // The castore services addresses
    #[clap(flatten)]
    pub service_addrs: ServiceUrlsGrpc,
    /// The root directory digest to serve.
    #[arg(short, long, help = "The root directory digest to serve")]
    pub root_directory: B3Digest,
    /// The name of the file to serve if a client requests a directory e.g. index.html index.htm
    #[arg(
        short,
        long,
        help = "The name of the file to serve if a client requests a directory e.g. index.html index.htm"
    )]
    pub index_names: Vec<String>,
    /// Whether a directory listing should be returned if a client requests a directory but none of the `index_names` matched
    #[arg(
        short,
        long,
        help = "Whether a directory listing should be returned if a client requests a directory but none of the `index_names` matched"
    )]
    pub auto_index: bool,
}
