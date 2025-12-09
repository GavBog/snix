use async_stream::try_stream;
use futures::StreamExt;
use futures::{Stream, stream::BoxStream};
use std::collections::{HashMap, HashSet, hash_map};
use tracing::warn;

use super::Directory;
use crate::{B3Digest, Node};

/// Emitted when directories are sent in the wrong order
#[derive(thiserror::Error, Debug, Eq, PartialEq)]
pub enum OrderingError {
    #[error("wrong size {size} for digest {digest}")]
    WrongSize { digest: B3Digest, size: u64 },

    #[error("unknown digest {digest} referenced for {path_component} in parent {parent_digest}")]
    UnknownLTR {
        digest: B3Digest,
        parent_digest: B3Digest,
        path_component: crate::PathComponent,
    },

    #[error("unexpected Directory with digest {0} encountered", directory.digest())]
    Unexpected { directory: Directory },

    #[error("some directories missing")]
    DirectoriesMissing(HashSet<B3Digest>),

    #[error("no directories received")]
    EmptySet,
}

/// A struct holding state while consuming a sequence of Directories in
/// Root-To-Leaves order.
///
/// It allows querying whether a certain digest could be acceptable
/// (to be able to skip parsing entirely if present in serialized form)
///
/// Validates that newly received directories are already referenced from
/// the root via existing directories.
/// It also ensures the actual directory sizes are the same as the sizes
/// communicated previously alongside the pointers.
/// Commonly used when _receiving_ a directory closure _from_ a store.
///
/// Internally keeps a list of digests introduced (pointers in previously
/// received directories), to recognize getting sent unrelated directories,
/// as well as a list of introduced, but not yet received digest (to detect
/// still-missing directories).
pub struct RootToLeavesValidator {
    /// directory digest introduced so far, and the sizes they are expected to have.
    introduced_directories: HashMap<B3Digest, u64>,

    /// the subset of `introduced_directories` that we still wait to receive.
    pending_directories: HashSet<B3Digest>,

    /// tracks whether [Self::finalize] has been called,
    /// or an error has occured while trying to accept.
    poison: bool,
}

impl RootToLeavesValidator {
    /// Initialize with the passed root directory
    /// That directory is implicitly accepted and should not be sent again
    pub fn new_with_root(directory: &Directory) -> Self {
        let mut this = Self {
            introduced_directories: HashMap::from_iter([(directory.digest(), directory.size())]),
            pending_directories: Default::default(),
            poison: false,
        };
        this.introduce_children_of(directory);
        this
    }

    /// Checks a directory digest on whether it's introduced.
    /// Particularly useful when receiving directories in canonical protobuf
    /// encoding, so that directories not connected to the root can be rejected
    /// without parsing.
    ///
    /// After parsing, the directory can be passed to [Self::try_accept]
    /// to add its children to the list of expected digests.
    pub fn would_accept(&self, digest: &B3Digest) -> bool {
        assert!(!self.poison, "Snix bug: RootToLeavesValidator poisoned");
        self.introduced_directories.contains_key(digest)
    }

    /// Accepts a directory if previously introduced, or returns an error if it's unknown.
    pub fn try_accept(&mut self, directory: &Directory) -> Result<(), OrderingError> {
        assert!(!self.poison, "Snix bug: RootToLeavesValidator poisoned");

        // every incoming directory must already have been introduced.
        let size = directory.size();
        let digest = directory.digest();

        match self.introduced_directories.get(&digest) {
            Some(s) if *s == size => {
                if !self.pending_directories.remove(&digest) {
                    warn!("directory received multiple times");
                };

                // Introduce children
                self.introduce_children_of(directory);
                Ok(())
            }
            Some(_) => {
                self.poison = true;
                Err(OrderingError::WrongSize { digest, size })
            }
            None => {
                self.poison = true;
                Err(OrderingError::Unexpected {
                    directory: directory.clone(),
                })
            }
        }
    }

    /// Should be called after accepting the last Directory
    /// Ensures there's no more pending directories.
    pub fn finalize(mut self) -> Result<(), OrderingError> {
        // At the end of the stream, pending must be empty.
        if !self.pending_directories.is_empty() {
            return Err(OrderingError::DirectoriesMissing(
                self.pending_directories.clone(),
            ));
        }

        self.poison = true;

        Ok(())
    }

    // Adds each child node to introduced_directories and pending_directories.
    fn introduce_children_of(&mut self, directory: &Directory) {
        for (_name, node) in directory.nodes() {
            if let Node::Directory { digest, size } = node {
                // if there's a pointer to a new directory
                if self
                    .introduced_directories
                    .insert(digest.to_owned(), *size)
                    .is_none()
                {
                    self.pending_directories.insert(digest.to_owned());
                }
            }
        }
    }

    /// This receives a stream of Directories, validating them to be in Root-To-Leaves order.
    /// If the order is correct, they are yielded wrapped in an Ok().
    /// If not, we yield an error.
    pub fn validate_stream<'s, S>(directories: S) -> BoxStream<'s, Result<Directory, OrderingError>>
    where
        S: Stream<Item = Directory> + Send + 's,
    {
        let mut directories = directories.boxed();

        Box::pin(try_stream! {
            // in the else case (empty stream), we emit an empty stream.
            if let Some(first_incoming_directory) = directories.next().await {
                let mut validator = RootToLeavesValidator::new_with_root(&first_incoming_directory);

                while let Some(incoming_directory) = directories.next().await {
                    validator.try_accept(&incoming_directory)?;
                    yield incoming_directory;
                }

                validator.finalize()?;
            }

        })
    }
}

#[derive(Default)]
/// A struct holding state while consuming a sequence of Directories in
/// Leaves-To-Root order.
///
/// Validates that newly accepted directories only reference directories which
/// have already been accepted before, and that the sizes attached alongside the
/// pointers match the actual sizes.
/// Commonly used when _uploading_ a directory closure _to_ a store.
pub struct LeavesToRootValidator {
    /// tracks inserted directories, and their sizes observed.
    accepted_directories: HashMap<B3Digest, u64>,

    /// tracks seen directories which are not yet referenced by parents.
    /// (root candidates)
    pending_directories: HashSet<B3Digest>,

    /// Tracks the last received digest
    #[cfg(debug_assertions)]
    last_inserted_digest: Option<B3Digest>,

    /// tracks whether [Self::finalize] has been called,
    /// or an error has occured while trying to accept.
    poison: bool,
}

impl LeavesToRootValidator {
    pub fn new() -> Self {
        Self {
            accepted_directories: Default::default(),
            pending_directories: Default::default(),
            #[cfg(debug_assertions)]
            last_inserted_digest: None,
            poison: false,
        }
    }

    /// Accepts a directory if previously introduced, or returns an error if it's unknown.
    pub fn try_accept(&mut self, directory: &Directory) -> Result<(), OrderingError> {
        assert!(!self.poison, "Snix bug: LeavesToRootValidator poisoned");

        // every directory referenced must already have been seen.
        // Remove them from pending if still in there.
        for (name, node) in directory.nodes() {
            if let Node::Directory { digest, size } = node {
                match self.accepted_directories.get(digest) {
                    Some(s) if s == size => {
                        self.pending_directories.remove(digest);
                    }
                    Some(s) => {
                        self.poison = true;
                        Err(OrderingError::WrongSize {
                            digest: digest.to_owned(),
                            size: *s,
                        })?
                    }
                    None => {
                        self.poison = true;
                        Err(OrderingError::UnknownLTR {
                            digest: digest.to_owned(),
                            parent_digest: directory.digest(),
                            path_component: name.to_owned(),
                        })?
                    }
                }
            }
        }

        // All elements were checked to only refer to directories previously seen,
        // we can accept the directory, and add it to pending.
        let directory_digest = directory.digest();
        match self.accepted_directories.entry(directory_digest) {
            hash_map::Entry::Occupied(_) => {
                warn!("directory received multiple times");
            }
            hash_map::Entry::Vacant(entry) => {
                entry.insert(directory.size());
                #[cfg(debug_assertions)]
                {
                    self.last_inserted_digest = Some(directory_digest)
                }
                self.pending_directories.insert(directory_digest);
            }
        }

        Ok(())
    }

    /// Should be called before Drop, to ensure there's no introduced but unsent
    /// directories.
    #[allow(unused_mut)]
    pub fn finalize(mut self) -> Result<(), OrderingError> {
        assert!(!self.poison, "Snix bug: LeavesToRootValidator poisoned");

        if self.accepted_directories.is_empty() {
            return Err(OrderingError::EmptySet);
        }

        // At the end, there may only be one unreferenced directory
        // (which is the root)
        if self.pending_directories.len() != 1 {
            Err(OrderingError::DirectoriesMissing(
                self.pending_directories.clone(),
            ))?
        }
        #[cfg(debug_assertions)]
        {
            let last_inserted_digest = self
                .last_inserted_digest
                .expect("Snix bug: have dangling_directories, but no last_inserted_digest");
            self.pending_directories
                .get(&last_inserted_digest)
                .expect("Snix bug: dangling directory is not last inserted one");
            self.poison = true;
        }

        Ok(())
    }

    /// This receives a stream of Directories, validating them to be in Leaves-To-Root order.
    /// If the order is correct, they are yielded wrapped in an Ok().
    /// If not, we yield an error.
    pub fn validate_stream<'s, S>(directories: S) -> BoxStream<'s, Result<Directory, OrderingError>>
    where
        S: Stream<Item = Directory> + Send + 's,
    {
        let mut directories = directories.boxed();
        let mut validator = Self::new();

        Box::pin(try_stream! {
            while let Some(directory) = directories.next().await {
                validator.try_accept(&directory)?;
                yield directory;
            }

            validator.finalize()?;
        })
    }
}

#[cfg(test)]
mod tests {
    use super::{LeavesToRootValidator, RootToLeavesValidator};
    use crate::directoryservice::Directory;
    use crate::fixtures::{DIRECTORY_A, DIRECTORY_B, DIRECTORY_C, DIRECTORY_D, DIRECTORY_E};
    use rstest::rstest;

    #[rstest]
    /// Uploading an empty directory should succeed.
    #[case::empty_directory(&[&*DIRECTORY_A], false, false)]
    /// Uploading A, then B (referring to A) should succeed.
    #[case::simple_closure(&[&*DIRECTORY_A, &*DIRECTORY_B], false, false)]
    /// Uploading A, then A, then C (referring to A twice) should succeed.
    /// We pretend to be a dumb client not deduping directories.
    #[case::same_child(&[&*DIRECTORY_A, &*DIRECTORY_A, &*DIRECTORY_C], false, false)]
    /// Uploading A, then C (referring to A twice) should succeed.
    #[case::same_child_dedup(&[&*DIRECTORY_A, &*DIRECTORY_C], false, false)]
    /// Uploading A, then C (referring to A twice), then B (itself referring to A) should fail during close,
    /// as B itself would be left unconnected.
    #[case::unconnected_node(&[&*DIRECTORY_A, &*DIRECTORY_C, &*DIRECTORY_B], false, true)]
    /// Uploading B (referring to A) should fail immediately, because A was never uploaded.
    #[case::dangling_pointer(&[&*DIRECTORY_B], true, false)]
    /// An empty set is disallowed.
    #[case::empty(&[], false, true)]
    fn leaves_to_root(
        #[case] directories_to_upload: &[&Directory],
        #[case] exp_fail_upload_last: bool,
        #[case] exp_fail_finalize: bool,
    ) {
        let mut validator = LeavesToRootValidator::default();
        let mut it = directories_to_upload.iter().peekable();

        while let Some(d) = it.next() {
            if it.peek().is_none() /* is last */ && exp_fail_upload_last {
                validator
                    .try_accept(d)
                    .expect_err("last try_accept to fail");
            } else {
                assert!(validator.try_accept(d).is_ok(), "try_accept to succeed");
            }
        }

        if !exp_fail_upload_last {
            if !exp_fail_finalize {
                validator.finalize().expect("finalize to succeed");
            } else {
                let _ = validator.finalize();
            }
        }
    }

    #[rstest]
    /// Downloading an empty directory should succeed.
    #[case::empty_directory(&*DIRECTORY_A, &[], false)]
    /// Downlading B, then A (referenced by B) should succeed.
    #[case::simple_closure(&*DIRECTORY_B, &[&*DIRECTORY_A], false)]
    /// Downloading C (referring to A twice), then A should succeed.
    #[case::same_child_dedup(&*DIRECTORY_C, &[&*DIRECTORY_A], false)]
    /// Downloading C, then A twice should succeed.
    #[case::same_child_redundant(&*DIRECTORY_C, &[&*DIRECTORY_A, &*DIRECTORY_A], false)]
    /// Downloading C, then A should succeed, even if we receive C twice
    #[case::with_root_sent_twice(&*DIRECTORY_C, &[&*DIRECTORY_C, &*DIRECTORY_A], false)]
    /// Downloading E -> D -> A,B should succeed.
    #[case::more_levels(&*DIRECTORY_E, &[&*DIRECTORY_D, &*DIRECTORY_A, &*DIRECTORY_B], false)]
    /// Downloading C, then B (both referring to A but not referring to each other) should fail immediately as B has no connection to C (the root)
    #[case::unconnected_node(&*DIRECTORY_C, &[&*DIRECTORY_B], true)]
    fn root_to_leaves(
        #[case] root: &Directory,
        #[case] directories_to_upload: &[&Directory],
        #[case] exp_fail_upload_last: bool,
    ) {
        let mut validator = RootToLeavesValidator::new_with_root(root);
        let mut it = directories_to_upload.iter().peekable();

        while let Some(d) = it.next() {
            if it.peek().is_none() /* is last */ && exp_fail_upload_last {
                assert!(
                    !validator.would_accept(&d.digest()),
                    "would_accept not expected to accept last failing element"
                );

                validator
                    .try_accept(d)
                    .expect_err("last try_accept to fail");
            } else {
                assert!(
                    validator.would_accept(&d.digest()),
                    "would_accept expected to accept directory"
                );
                assert!(validator.try_accept(d).is_ok(), "try_accept to succeed");
            }
        }

        if !exp_fail_upload_last {
            validator.finalize().expect("finalize to succeed");
        }
    }
}
