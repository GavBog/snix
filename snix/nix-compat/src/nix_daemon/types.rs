use crate::nixbase32;
use crate::wire::de::Error;
use crate::{
    narinfo::Signature,
    nixhash::CAHash,
    store_path::StorePath,
    wire::{
        de::{NixDeserialize, NixRead},
        ser::{NixSerialize, NixWrite},
    },
};
use nix_compat_derive::{NixDeserialize, NixSerialize};

/// Marker type that consumes/sends and ignores a u64.
#[derive(Clone, Debug, NixDeserialize, NixSerialize)]
#[nix(from = "u64", into = "u64")]
pub struct IgnoredZero;
impl From<u64> for IgnoredZero {
    fn from(_: u64) -> Self {
        IgnoredZero
    }
}

impl From<IgnoredZero> for u64 {
    fn from(_: IgnoredZero) -> Self {
        0
    }
}

#[derive(Debug, NixSerialize)]
pub struct TraceLine {
    have_pos: IgnoredZero,
    hint: String,
}

/// Represents an error returned by the nix-daemon to its client.
///
/// Adheres to the format described in serialization.md
#[derive(NixSerialize)]
pub struct NixError {
    #[nix(version = "26..")]
    type_: &'static str,

    #[nix(version = "26..")]
    level: u64,

    #[nix(version = "26..")]
    name: &'static str,

    msg: String,
    #[nix(version = "26..")]
    have_pos: IgnoredZero,

    #[nix(version = "26..")]
    traces: Vec<TraceLine>,

    #[nix(version = "..=25")]
    exit_status: u64,
}

impl NixError {
    pub fn new(msg: String) -> Self {
        Self {
            type_: "Error",
            level: 0, // error
            name: "Error",
            msg,
            have_pos: IgnoredZero {},
            traces: vec![],
            exit_status: 1,
        }
    }
}

impl NixSerialize for Option<UnkeyedValidPathInfo> {
    async fn serialize<W>(&self, writer: &mut W) -> Result<(), W::Error>
    where
        W: NixWrite,
    {
        match self {
            Some(value) => {
                writer.write_value(&true).await?;
                writer.write_value(value).await
            }
            None => writer.write_value(&false).await,
        }
    }
}

#[derive(NixSerialize, NixDeserialize, Debug, Clone, PartialEq)]
pub struct UnkeyedValidPathInfo {
    pub deriver: Option<StorePath>,
    pub nar_hash: NarHash,
    pub references: Vec<StorePath>,
    pub registration_time: u64,
    pub nar_size: u64,
    pub ultimate: bool,
    pub signatures: Vec<Signature<String>>,
    pub ca: Option<CAHash>,
}

/// Request tuple for [super::worker_protocol::Operation::QueryValidPaths]
#[derive(NixDeserialize)]
pub struct QueryValidPaths {
    // Paths to query
    pub paths: Vec<StorePath>,

    // Whether to try and substitute the paths.
    #[nix(version = "27..")]
    pub substitute: bool,
}

/// newtype wrapper for the byte array that correctly implements NixSerialize, NixDeserialize.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct NarHash([u8; 32]);

impl NarHash {
    pub fn from_digest(digest: [u8; 32]) -> Self {
        NarHash(digest)
    }
}

impl std::ops::Deref for NarHash {
    type Target = [u8; 32];

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl NixDeserialize for NarHash {
    async fn try_deserialize<R>(reader: &mut R) -> Result<Option<Self>, R::Error>
    where
        R: ?Sized + NixRead + Send,
    {
        if let Some(bytes) = reader.try_read_bytes().await? {
            let result = data_encoding::HEXLOWER
                .decode(bytes.as_ref())
                .map_err(R::Error::invalid_data)?;
            Ok(Some(NarHash(result.try_into().map_err(|_| {
                R::Error::invalid_data("incorrect length")
            })?)))
        } else {
            Ok(None)
        }
    }
}

impl NixSerialize for NarHash {
    async fn serialize<W>(&self, writer: &mut W) -> Result<(), W::Error>
    where
        W: NixWrite,
    {
        nixbase32::encode(&self.0).serialize(writer).await
    }
}

/// Info type used by [super::worker_protocol::Operation::AddToStoreNar] and [super::worker_protocol::Operation::AddMultipleToStore]
///
/// See: [ValidPathInfo reference](https://snix.dev/docs/reference/nix-daemon-protocol/types/#validpathinfo)
#[derive(NixDeserialize, Debug)]
pub struct ValidPathInfo {
    // - path :: [StorePath][se-StorePath]
    pub path: StorePath,
    pub info: UnkeyedValidPathInfo,
}
