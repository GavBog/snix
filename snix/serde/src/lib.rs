//! `snix-serde` implements (de-)serialisation of Rust data structures
//! to/from Nix. This is intended to make it easy to use Nix as as
//! configuration language.
#![cfg_attr(docsrs, feature(doc_cfg))]

mod de;
mod error;
mod ser;

pub use de::from_str;
pub use de::from_str_with_config;
pub use de::from_value;
pub use error::Error;
pub use ser::to_string;
pub use ser::to_value;

#[cfg(test)]
mod de_tests;
#[cfg(test)]
mod ser_tests;
