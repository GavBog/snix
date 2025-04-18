---
title: "Data Model"
summary: ""
date: 2025-04-04T16:16:37+00:00
lastmod: 2025-04-04T16:16:37+00:00
draft: false
weight: 41
toc: true
---

This describes the data model used in `snix-castore` to describe file system
trees. blob / chunk storage is covered by other documents.

For those familiar, `snix-castore` uses a similar concept as git tree objects,
which also is a merkle structure. [^why-not-git-trees]

## [Node][rustdoc-node]
`snix-castore` can represent three different types.
Nodes themselves don't have names, names are given by being in a
[Directory](#directory) structure.

### `Node::File`
A (regular) file.
We store the [BLAKE3][] digest of the raw file contents, the length of the raw
data, and an executable bit.

### `Node::Symlink`
A symbolic link.
We store the symlink target contents.

### `Node::Directory`
A (child) directory.
We store the digest of the [Directory](#directory) structure describing its
"contents".

We also store a `size` field, containing the (total) number of all child
elements in the referenced `Directory`, which helps for inode calculation.


## [Directory][rustdoc-node]
The Directory struct contains all nodes in a single directory (on that level),
alongside with their (base)names (called [PathComponent](#pathcomponent)).

`.` and `..` are not included.

For the Directory struct, a *Digest* can be calculated[^directory-digest], which
is what the parent `Node::Directory` will use as a reference, to build a merkle
structure.

## [PathComponent][rustdoc-pathcomponent]
This is a more strict version of bytes, reduced to valid path components in a
[Directory](#directory).

It disallows slashes, null bytes, `.`, `..` and the
empty string. It also rejects too long names (> 255 bytes).

## Merkle DAG
The pointers from `Node::File` to `Directory`, and this one potentially
containing `Node::File` again makes the whole structure a merkle tree  (or
strictly speaking, a graph, as two elements pointing to a child directory with
the same contents would point to the same `Directory` message).


## Protobuf
In addition to the Rust types described above, there's also a protobuf
representation, which differs slightly:

Instead of nodes being unnamed, and `Directory` containing a map from
`PathComponent` to `Node` (and keys being the basenames in that directory),
the `Directory` message contains three lists, `directories`, `files` and
`symlinks`, holding `DirectoryEntry`, `FileEntry` and `SymlinkEntry` messages
respectively.

These contain all fields present in the corresponding `Node` enum kind, as well
as a `name` field, representing the basename in that directory.

For reproducibility reasons, the lists MUST be sorted by that name and the
name MUST be unique across all three lists.


[rustdoc-directory]: https://snix.dev/rustdoc/snix_castore/struct.Directory.html
[rustdoc-node]: https://snix.dev/rustdoc/snix_castore/enum.Node.html
[rustdoc-pathcomponent]: https://snix.dev/rustdoc/snix_castore/struct.PathComponent.html
[BLAKE3]: https://github.com/BLAKE3-team/BLAKE3
[^why-not-git-trees]: For a detailed comparison with the git model, and what (and why we do differently, see [here]({{< relref "why-not-git.md" >}}))
[^directory-digest]: We currently use the [BLAKE3][] digest of the protobuf
                     serialization of the `proto::Directory` struct to calculate
                     these digests. While pretty stable across most
                     implementations, there's no guarantee this will always stay
                     as-is, so we might switch to another serialization with
                     stronger guarantees on that front in the future.
                     See [#111](https://git.snix.dev/snix/snix/issues/111) for details.
