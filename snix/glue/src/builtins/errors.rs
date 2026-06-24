//! Contains errors that can occur during evaluation of builtins in this crate
use nix_compat::{derivation::OutputName, nixhash::NixHash};
use std::{path::PathBuf, sync::Arc};
use thiserror::Error;

/// Errors related to derivation construction
#[derive(Debug, Error)]
pub enum DerivationError {
    #[error("an output with the name '{0}' is already defined")]
    DuplicateOutput(OutputName),
    #[error("fixed-output derivations can only have the default `out`-output")]
    ConflictingOutputTypes,
    #[error("the environment variable '{0}' has already been set in this derivation")]
    DuplicateEnvVar(String),
    #[error(
        "Cannot have an environment variable named '__json'. This key is reserved for encoding structured attrs"
    )]
    StructuredAttrsJsonKeyPresent,
    #[error("invalid derivation parameters: {0}")]
    InvalidDerivation(#[from] nix_compat::derivation::DerivationError),
}

impl From<DerivationError> for snix_eval::ErrorKind {
    fn from(err: DerivationError) -> Self {
        snix_eval::ErrorKind::SnixError(Arc::from(err))
    }
}

/// Errors related to `builtins.path` and `builtins.filterSource`,
/// a.k.a. "importing" builtins.
#[derive(Debug, Error)]
pub enum ImportError {
    #[error("non-file '{0}' cannot be imported in 'flat' mode")]
    FlatImportOfNonFile(PathBuf),

    #[error("hash mismatch at ingestion of '{0}', expected: '{1}', got: '{2}'")]
    HashMismatch(PathBuf, NixHash, NixHash),

    #[error("path '{}' is not absolute or invalid", .0.display())]
    PathNotAbsoluteOrInvalid(PathBuf),
}

impl From<ImportError> for snix_eval::ErrorKind {
    fn from(err: ImportError) -> Self {
        snix_eval::ErrorKind::SnixError(Arc::from(err))
    }
}
