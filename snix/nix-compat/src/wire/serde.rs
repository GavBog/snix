mod derived_path {
    use crate::derived_path::{DerivedPath, LegacyDerivedPath};
    use nix_compat_derive::nix_serde_remote;

    nix_serde_remote!(
        #[nix(into = "LegacyDerivedPath", from = "LegacyDerivedPath")]
        DerivedPath
    );
    nix_serde_remote!(
        #[nix(from_str, display)]
        LegacyDerivedPath
    );
}

mod int {
    use nix_compat_derive::{nix_deserialize_remote, nix_serde_remote};

    nix_deserialize_remote!(
        #[nix(try_from = "u64")]
        u8
    );
    nix_serde_remote!(
        #[nix(try_from = "u64", into = "u64")]
        u16
    );
    nix_serde_remote!(
        #[nix(try_from = "u64", into = "u64")]
        u32
    );
    nix_serde_remote!(
        #[nix(try_from = "u64", try_into = "u64")]
        i64
    );
}

mod log {
    nix_compat_derive::nix_serde_remote!(
        #[nix(try_from = "u64", into = "u64")]
        crate::log::VerbosityLevel
    );
}

mod narinfo {
    use crate::narinfo::Signature;
    use crate::wire::de::{NixDeserialize, NixRead};

    nix_compat_derive::nix_serialize_remote!(#[nix(display)] Signature<String>);

    impl NixDeserialize for Signature<String> {
        async fn try_deserialize<R>(reader: &mut R) -> Result<Option<Self>, R::Error>
        where
            R: ?Sized + NixRead + Send,
        {
            use crate::wire::de::Error;
            let value: Option<String> = reader.try_read_value().await?;
            match value {
                Some(value) => Ok(Some(
                    Signature::<String>::parse(&value).map_err(R::Error::invalid_data)?,
                )),
                None => Ok(None),
            }
        }
    }
}

mod nixhash {
    use nix_compat_derive::nix_serde_remote;

    use crate::nixhash::{CAHash, HashAlgo};
    use crate::wire::de::{NixDeserialize, NixRead};
    use crate::wire::ser::{NixSerialize, NixWrite};

    nix_serde_remote!(
        #[nix(display, from_str)]
        HashAlgo
    );

    impl NixSerialize for CAHash {
        async fn serialize<W>(&self, writer: &mut W) -> Result<(), W::Error>
        where
            W: NixWrite,
        {
            writer.write_value(&self.to_string()).await
        }
    }

    impl NixDeserialize for CAHash {
        async fn try_deserialize<R>(reader: &mut R) -> Result<Option<Self>, R::Error>
        where
            R: ?Sized + NixRead + Send,
        {
            use crate::wire::de::Error;
            let value: Option<String> = reader.try_read_value().await?;
            match value {
                Some(value) => Ok(Some(CAHash::from_nix_hex_str(&value).ok_or_else(|| {
                    R::Error::invalid_data(format!("Invalid cahash {value}"))
                })?)),
                None => Ok(None),
            }
        }
    }

    impl NixSerialize for Option<CAHash> {
        async fn serialize<W>(&self, writer: &mut W) -> Result<(), W::Error>
        where
            W: NixWrite,
        {
            match self {
                Some(value) => writer.write_value(value).await,
                None => writer.write_value("").await,
            }
        }
    }

    impl NixDeserialize for Option<CAHash> {
        async fn try_deserialize<R>(reader: &mut R) -> Result<Option<Self>, R::Error>
        where
            R: ?Sized + NixRead + Send,
        {
            use crate::wire::de::Error;
            let value: Option<String> = reader.try_read_value().await?;
            match value {
                Some(value) => {
                    if value.is_empty() {
                        Ok(None)
                    } else {
                        Ok(Some(Some(CAHash::from_nix_hex_str(&value).ok_or_else(
                            || R::Error::invalid_data(format!("Invalid cahash {value}")),
                        )?)))
                    }
                }
                None => Ok(None),
            }
        }
    }
}

mod store_path {
    use crate::store_path::StorePath;
    use crate::wire::de::{NixDeserialize, NixRead};
    use crate::wire::ser::{NixSerialize, NixWrite};

    // Custom implementation since FromStr does not use from_absolute_path
    impl NixDeserialize for StorePath {
        async fn try_deserialize<R>(reader: &mut R) -> Result<Option<Self>, R::Error>
        where
            R: ?Sized + NixRead + Send,
        {
            use crate::wire::de::Error;
            if let Some(buf) = reader.try_read_bytes().await? {
                let result = StorePath::from_absolute_path(&buf);
                result.map(Some).map_err(R::Error::invalid_data)
            } else {
                Ok(None)
            }
        }
    }

    // Custom implementation since Display does not use absolute paths.
    impl NixSerialize for StorePath {
        fn serialize<W>(&self, writer: &mut W) -> impl Future<Output = Result<(), W::Error>> + Send
        where
            W: NixWrite,
        {
            let sp = self.as_absolute_path_fmt();
            async move { writer.write_display(&sp).await }
        }
    }

    impl NixDeserialize for Option<StorePath> {
        async fn try_deserialize<R>(reader: &mut R) -> Result<Option<Self>, R::Error>
        where
            R: ?Sized + NixRead + Send,
        {
            use crate::wire::de::Error;
            if let Some(buf) = reader.try_read_bytes().await? {
                if buf.is_empty() {
                    Ok(Some(None))
                } else {
                    let result = StorePath::from_absolute_path(&buf);
                    result
                        .map(|r| Some(Some(r)))
                        .map_err(R::Error::invalid_data)
                }
            } else {
                Ok(Some(None))
            }
        }
    }

    // Writes StorePath or an empty string.
    impl NixSerialize for Option<StorePath> {
        async fn serialize<W>(&self, writer: &mut W) -> Result<(), W::Error>
        where
            W: NixWrite,
        {
            match self {
                Some(value) => writer.write_value(value).await,
                None => writer.write_value("").await,
            }
        }
    }
}
