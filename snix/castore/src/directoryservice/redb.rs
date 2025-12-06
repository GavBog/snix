use futures::{StreamExt, stream::BoxStream};
use prost::Message;
use redb::{ReadableDatabase, TableDefinition};
use std::{path::PathBuf, sync::Arc};
use tonic::async_trait;
use tracing::{instrument, warn};

use super::{Directory, DirectoryPutter, DirectoryService, traverse_directory};
use crate::{
    B3Digest, Error,
    composition::{CompositionContext, ServiceBuilder},
    directoryservice::directory_graph::DirectoryGraphBuilder,
    proto,
};

const DIRECTORY_TABLE: TableDefinition<[u8; B3Digest::LENGTH], Vec<u8>> =
    TableDefinition::new("directory");

enum Db {
    ReadOnly(redb::ReadOnlyDatabase),
    ReadWrite(redb::Database),
}

impl Db {
    fn begin_read(&self) -> Result<redb::ReadTransaction, redb::TransactionError> {
        match self {
            Db::ReadOnly(db) => db.begin_read(),
            Db::ReadWrite(db) => db.begin_read(),
        }
    }

    fn begin_write(&self) -> Result<redb::WriteTransaction, Error> {
        match self {
            Db::ReadOnly(_) => Err(Error::StorageError(
                "unable to open write txn, database is opened read-only".to_string(),
            )),
            Db::ReadWrite(db) => Ok(db.begin_write()?),
        }
    }
}

#[derive(Clone)]
pub struct RedbDirectoryService {
    instance_name: String,

    /// An Arc'ed Database, read-only or writeable.
    db: Arc<Db>,
}

impl RedbDirectoryService {
    /// Constructs a new instance using the specified config.
    pub async fn new(
        instance_name: String,
        config: RedbDirectoryServiceConfig,
    ) -> Result<Self, Error> {
        if let Some(path) = config.path.clone() {
            if &path == "" {
                return Err(Error::StorageError("empty path is disallowed".to_string()));
            }
            if &path == "/" {
                return Err(Error::StorageError(
                    "cowardly refusing to open / with redb".to_string(),
                ));
            }

            if config.read_only {
                let db =
                    tokio::task::spawn_blocking(|| redb::Database::builder().open_read_only(path))
                        .await??;

                return Ok(Self {
                    instance_name,
                    db: Arc::new(Db::ReadOnly(db)),
                });
            }

            if let Some(parent) = path.parent() {
                tokio::fs::create_dir_all(parent).await?;
            }

            let db = tokio::task::spawn_blocking(move || {
                let mut builder = redb::Database::builder();
                configure_builder(&mut builder, &config);

                let db = builder.create(path)?;
                create_schema(&db)?;
                Ok::<_, redb::Error>(db)
            })
            .await??;

            Ok(Self {
                instance_name,
                db: Arc::new(Db::ReadWrite(db)),
            })
        } else {
            Self::new_temporary(instance_name, config)
        }
    }

    /// Constructs a new instance using the in-memory backend.
    /// Sync, as there's no real IO happening.
    pub fn new_temporary(
        instance_name: String,
        config: RedbDirectoryServiceConfig,
    ) -> Result<Self, Error> {
        debug_assert!(
            config.path.is_none(),
            "Snix bug: config.path is not None, but new_temporary requested"
        );

        if config.read_only {
            return Err(Error::StorageError(
                "in-memory database cannot be read-only".to_string(),
            ));
        }

        let mut builder = redb::Database::builder();
        configure_builder(&mut builder, &config);

        let db = builder.create_with_backend(redb::backends::InMemoryBackend::new())?;

        create_schema(&db)?;

        Ok(Self {
            instance_name,
            db: Arc::new(Db::ReadWrite(db)),
        })
    }
}

/// Applies options from [RedbDirectoryServiceConfig] to a [redb::Builder].
fn configure_builder(builder: &mut redb::Builder, config: &RedbDirectoryServiceConfig) {
    if let Some(cache_size) = config.cache_size {
        builder.set_cache_size(cache_size);
    }
}

/// Ensures all tables are present.
/// Opens a write transaction and calls open_table on DIRECTORY_TABLE, which will
/// create it if not present.
#[allow(clippy::result_large_err)]
fn create_schema(db: &redb::Database) -> Result<(), redb::Error> {
    let txn = db.begin_write()?;
    txn.open_table(DIRECTORY_TABLE)?;
    txn.commit()?;

    Ok(())
}

#[async_trait]
impl DirectoryService for RedbDirectoryService {
    #[instrument(skip(self, digest), fields(directory.digest = %digest, instance_name = %self.instance_name))]
    async fn get(&self, digest: &B3Digest) -> Result<Option<Directory>, Error> {
        let db = self.db.clone();
        let digest = *digest;
        // Retrieves the protobuf-encoded Directory for the corresponding digest.
        let db_get_resp = tokio::task::spawn_blocking(move || -> Result<_, redb::Error> {
            let txn = db.begin_read()?;
            let table = txn.open_table(DIRECTORY_TABLE)?;
            Ok(table.get(*digest)?)
        })
        .await?
        .map_err(|e| {
            warn!(err=%e, "failed to retrieve Directory");
            Error::StorageError("failed to retrieve Directory".to_string())
        })?;

        // The Directory was not found, return None.
        let directory_data = match db_get_resp {
            None => return Ok(None),
            Some(d) => d,
        };

        // We check that the digest of the retrieved Directory matches the expected digest.
        let actual_digest = blake3::hash(directory_data.value().as_slice());
        if actual_digest.as_bytes() != digest.as_slice() {
            warn!(directory.actual_digest=%actual_digest, "requested Directory got the wrong digest");
            return Err(Error::StorageError(
                "requested Directory got the wrong digest".to_string(),
            ));
        }

        // Attempt to decode the retrieved protobuf-encoded Directory, returning a parsing error if
        // the decoding failed.
        let directory = match proto::Directory::decode(&*directory_data.value()) {
            Ok(dir) => {
                // The returned Directory must be valid.
                dir.try_into().map_err(|e| {
                    warn!(err=%e, "Directory failed validation");
                    Error::StorageError("Directory failed validation".to_string())
                })?
            }
            Err(e) => {
                warn!(err=%e, "failed to parse Directory");
                return Err(Error::StorageError("failed to parse Directory".to_string()));
            }
        };

        Ok(Some(directory))
    }

    #[instrument(skip(self, directory), fields(directory.digest = %directory.digest(), instance_name = %self.instance_name))]
    async fn put(&self, directory: Directory) -> Result<B3Digest, Error> {
        let db = self.db.clone();
        tokio::task::spawn_blocking(move || {
            let digest = directory.digest();

            // Store the directory in the table.
            let txn = db.begin_write()?;
            {
                let mut table = txn.open_table(DIRECTORY_TABLE)?;
                table.insert(
                    digest.as_ref(),
                    proto::Directory::from(directory).encode_to_vec(),
                )?;
            }
            txn.commit()?;

            Ok(digest)
        })
        .await?
    }

    #[instrument(skip_all, fields(directory.digest = %root_directory_digest, instance_name = %self.instance_name))]
    fn get_recursive(
        &self,
        root_directory_digest: &B3Digest,
    ) -> BoxStream<'static, Result<Directory, Error>> {
        // FUTUREWORK: Ideally we should have all of the directory traversing happen in a single
        // redb transaction to avoid constantly closing and opening new transactions for the
        // database.
        traverse_directory(self.clone(), *root_directory_digest).boxed()
    }

    #[instrument(skip_all)]
    fn put_multiple_start(&self) -> Box<dyn DirectoryPutter + '_> {
        Box::new(RedbDirectoryPutter {
            db: &self.db,
            builder: Some(DirectoryGraphBuilder::new_leaves_to_root()),
        })
    }
}

pub struct RedbDirectoryPutter<'a> {
    db: &'a Db,

    /// The directories (inside the directory validator) that we insert later,
    /// or None, if they were already inserted.
    builder: Option<DirectoryGraphBuilder>,
}

#[async_trait]
impl DirectoryPutter for RedbDirectoryPutter<'_> {
    #[instrument(level = "trace", skip_all, fields(directory.digest=%directory.digest()), err)]
    async fn put(&mut self, directory: Directory) -> Result<(), Error> {
        let builder = self
            .builder
            .as_mut()
            .ok_or_else(|| Error::StorageError("already closed".to_string()))?;

        builder.try_insert(directory)?;

        Ok(())
    }

    #[instrument(level = "trace", skip_all, ret, err)]
    async fn close(&mut self) -> Result<B3Digest, Error> {
        let builder = self
            .builder
            .take()
            .ok_or_else(|| Error::StorageError("already closed".to_string()))?;

        // Insert all directories as a batch.
        tokio::task::spawn_blocking({
            let txn = self.db.begin_write()?;
            move || {
                // Retrieve the validated directories.
                let directory_graph = builder.build()?;
                let root_digest = directory_graph.root().digest();

                // Looping over all the verified directories, queuing them up for a
                // batch insertion.
                {
                    let mut table = txn.open_table(DIRECTORY_TABLE)?;
                    for directory in directory_graph.drain_leaves_to_root() {
                        table.insert(
                            directory.digest().as_ref(),
                            proto::Directory::from(directory).encode_to_vec(),
                        )?;
                    }
                }
                txn.commit()?;

                Ok(root_digest)
            }
        })
        .await?
    }
}

#[derive(Clone, Default, serde::Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RedbDirectoryServiceConfig {
    path: Option<PathBuf>,

    /// The amount of memory (in bytes) used for caching data
    cache_size: Option<usize>,

    /// Whether to open read-only.
    #[serde(default)]
    read_only: bool,
}

impl TryFrom<url::Url> for RedbDirectoryServiceConfig {
    type Error = Box<dyn std::error::Error + Send + Sync>;

    fn try_from(url: url::Url) -> Result<Self, Self::Error> {
        if url.has_host() {
            return Err(Error::StorageError("no host allowed".to_string()).into());
        }

        let path: Option<PathBuf> = match (url.scheme(), url.has_authority(), url.path()) {
            ("redb+memory", false, "") => None,
            ("redb+memory", false, _) => Err(Box::new(Error::StorageError(
                "redb+memory with path is disallowed".to_string(),
            )))?,
            ("redb+memory", true, _) => Err(Box::new(Error::StorageError(
                "redb+memory may not have authority".to_string(),
            )))?,
            ("redb", _, "") => Err(Box::new(Error::StorageError(
                "redb without path is disallowed, use redb+memory if you want in-memory"
                    .to_string(),
            )))?,
            ("redb", _, path) => Some(path.into()),
            (_scheme, _, _) => Err(Box::new(Error::StorageError(
                "Unrecognized scheme".to_string(),
            )))?,
        };

        let mut config: RedbDirectoryServiceConfig =
            serde_qs::from_str(url.query().unwrap_or_default())
                .map_err(|e| Error::InvalidRequest(format!("failed to parse parameters: {e}")))?;

        config.path = path;

        Ok(config)
    }
}

#[async_trait]
impl ServiceBuilder for RedbDirectoryServiceConfig {
    type Output = dyn DirectoryService;
    async fn build<'a>(
        &'a self,
        instance_name: &str,
        _context: &CompositionContext,
    ) -> Result<Arc<dyn DirectoryService>, Box<dyn std::error::Error + Send + Sync + 'static>> {
        Ok(Arc::new(
            RedbDirectoryService::new(instance_name.to_string(), self.to_owned()).await?,
        ))
    }
}

#[cfg(test)]
mod tests {
    use tempfile::TempDir;

    use crate::{
        directoryservice::{DirectoryService, RedbDirectoryService, RedbDirectoryServiceConfig},
        fixtures::DIRECTORY_A,
    };

    #[tokio::test]
    async fn reopen_as_read_only() {
        let tempdir = TempDir::new().unwrap();
        let path = tempdir.path().join("data.redb");

        let config = RedbDirectoryServiceConfig {
            path: Some(path),
            cache_size: None,
            read_only: false,
        };

        // Create a read-write directory service and insert some data.
        {
            let directory_service = RedbDirectoryService::new("rw".to_string(), config.clone())
                .await
                .expect("to construct");

            directory_service
                .put(DIRECTORY_A.clone())
                .await
                .expect("to insert");
        } // we drop the rw database here.

        // Re-open the same path in ro mode (twice)
        let ro_config = RedbDirectoryServiceConfig {
            read_only: true,
            ..config
        };

        let directory_service_ro_1 =
            RedbDirectoryService::new("ro1".to_string(), ro_config.clone())
                .await
                .expect("to construct");
        let directory_service_ro_2 = RedbDirectoryService::new("ro2".to_string(), ro_config)
            .await
            .expect("to construct");

        assert_eq!(
            directory_service_ro_1
                .get(&DIRECTORY_A.digest())
                .await
                .expect("get to succeed")
                .expect("to be Some(_)")
                .digest(),
            DIRECTORY_A.digest()
        );
        assert_eq!(
            directory_service_ro_2
                .get(&DIRECTORY_A.digest())
                .await
                .expect("get to succeed")
                .expect("to be Some(_)")
                .digest(),
            DIRECTORY_A.digest()
        );
    }

    #[tokio::test]
    async fn read_only_nonexistent() {
        let tempdir = TempDir::new().unwrap();
        let path = tempdir.path().join("data.redb");

        let config = RedbDirectoryServiceConfig {
            path: Some(path),
            cache_size: None,
            read_only: true,
        };

        // Opening a read-only redb should fail if the path doesn't exist.
        assert!(
            RedbDirectoryService::new("test".to_string(), config)
                .await
                .is_err(),
            "opening new path r/o should fail"
        );
    }

    #[tokio::test]
    async fn open_rw_and_ro() {
        let tempdir = TempDir::new().unwrap();
        let path = tempdir.path().join("data.redb");

        let config = RedbDirectoryServiceConfig {
            path: Some(path),
            cache_size: None,
            read_only: false,
        };

        let _directory_service = RedbDirectoryService::new("rw".to_string(), config.clone())
            .await
            .expect("to construct");

        // Opening a read-only redb should fail if it's already opened read-write.
        assert!(
            RedbDirectoryService::new(
                "ro".to_string(),
                RedbDirectoryServiceConfig {
                    read_only: true,
                    ..config
                }
            )
            .await
            .is_err(),
            "opening r/o should fail if still open r/w"
        );
    }
}
