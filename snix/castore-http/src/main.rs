use snix_castore_http::cli::CliArgs;

use anyhow::{bail, Context};
use bytes::Bytes;
use clap::Parser;
use data_encoding::BASE64URL_NOPAD;
use prost::Message;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt().init();

    let CliArgs {
        listen_args,
        service_addrs,
        root_node,
        index_names,
        auto_index,
    }: CliArgs = snix_castore_http::cli::CliArgs::parse();

    // b64decode the root node passed *by the user*
    let root_entry_proto = BASE64URL_NOPAD
        .decode(root_node.as_bytes())
        .context("unable to decode root node b64")?;

    // check the proto size to be somewhat reasonable before parsing it.
    if root_entry_proto.len() > 4096 {
        bail!("rejected, too large root node");
    }

    // parse the proto
    let root_entry: snix_castore::proto::Entry = Message::decode(Bytes::from(root_entry_proto))
        .context("unable to decode root node proto")?;

    let root_node = root_entry
        .try_into_anonymous_node()
        .context("root node validation failed")?;

    snix_castore_http::router::gen_router(
        listen_args,
        service_addrs,
        root_node,
        &index_names,
        auto_index,
    )
    .await
}
