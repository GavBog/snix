use snix_castore::{Node, blobservice::BlobService, directoryservice::DirectoryService};

use std::sync::Arc;

pub type AppState = Arc<AppConfig>;

pub struct AppConfig {
    pub blob_service: Arc<dyn BlobService>,
    pub directory_service: Arc<dyn DirectoryService>,
    pub root_node: Node,
    pub index_names: Vec<String>,
    pub auto_index: bool,
}
