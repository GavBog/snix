use nix_compat::nixhash::NixHash;
use nix_compat::store_path;
use snix_castore::import;
use url::Url;

#[derive(Debug, thiserror::Error)]
pub enum FetcherError {
    #[error("hash mismatch in file downloaded from {url}:\n  wanted: {wanted}\n     got: {got}")]
    HashMismatch {
        url: Url,
        wanted: NixHash,
        got: NixHash,
    },

    #[error("Invalid hash type '{0}' for fetcher")]
    InvalidHashType(&'static str),

    #[error("Unable to parse URL: {0}")]
    InvalidUrl(#[from] url::ParseError),

    #[error(transparent)]
    Http(#[from] reqwest::Error),

    #[error(transparent)]
    Io(#[from] std::io::Error),

    #[error(transparent)]
    Import(#[from] snix_castore::import::IngestionError<import::archive::Error>),

    #[error("Error calculating store path for fetcher output: {0}")]
    StorePath(#[from] store_path::ParseStorePathError),
}
