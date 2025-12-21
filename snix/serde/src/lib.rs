//! `snix-serde` implements (de-)serialisation of Rust data structures
//! to/from Nix. This is intended to make it easy to use Nix as as
//! configuration language.
#![cfg_attr(docsrs, feature(doc_cfg))]

mod de;
mod error;

pub use de::from_str;
pub use de::from_str_with_config;

#[cfg(test)]
mod de_tests;
