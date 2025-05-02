use crate::app_state::{AppConfig, AppState};
use crate::routes;

use snix_castore::Node;
use snix_castore::utils::ServiceUrlsGrpc;

use axum::{Router, routing::get};
use std::sync::Arc;
use tokio_listener::ListenerAddressLFlag;
use tracing::info;

/// Runs the snix-castore-http server given the specified CLI arguments
pub async fn gen_router(
    listen_args: ListenerAddressLFlag,
    service_addrs: ServiceUrlsGrpc,
    root_node: Node,
    index_names: &[String],
    auto_index: bool,
) -> anyhow::Result<()> {
    let (blob_service, directory_service) = snix_castore::utils::construct_services(service_addrs)
        .await
        .expect("failed to construct services");

    let app_state = Arc::new(AppConfig {
        blob_service,
        directory_service,
        root_node,
        index_names: index_names.to_vec(),
        auto_index,
    });

    let app = app(app_state);

    let listen_address = &listen_args.listen_address.unwrap_or_else(|| {
        "[::]:9000"
            .parse()
            .expect("invalid fallback listen address")
    });

    let listener = tokio_listener::Listener::bind(
        listen_address,
        &Default::default(),
        &listen_args.listener_options,
    )
    .await?;

    info!(listen_address=%listen_address, "starting daemon");

    tokio_listener::axum07::serve(
        listener,
        app.into_make_service_with_connect_info::<tokio_listener::SomeSocketAddrClonable>(),
    )
    .await?;
    Ok(())
}

pub fn app(app_state: AppState) -> Router {
    Router::new()
        .route("/*path", get(routes::root_node_contents))
        .route("/", get(routes::root_node_contents))
        .with_state(app_state)
}
