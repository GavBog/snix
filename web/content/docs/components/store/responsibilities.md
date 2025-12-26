---
title: "Responsibilities"
date: 2025-12-26T09:53:18+01:00
lastmod: 2025-12-26T09:53:18+01:00
weight: 10
toc: false
---

Store takes care of storing build results. It provides a
unified interface to get store paths and upload new ones, as well as querying
for the existence of a store path and its metadata (references, signatures, …).

Snix natively uses an improved store protocol. Instead of transferring around
NAR files, which don't provide an index and don't allow seekable access, a
concept similar to git tree hashing is used.

This allows more granular substitution, chunk reusage and parallel download of
individual files, reducing bandwidth usage.
As these chunks are content-addressed, it opens up the potential for
peer-to-peer trustless substitution of most of the data, as long as we sign the
root of the index.

Snix still keeps the old-style signatures, NAR hashes and NAR size around. In
the case of NAR hash / NAR size, this data is strictly required in some cases.
The old-style signatures are valuable for communication with existing
implementations.

Old-style binary caches (like cache.nixos.org) can still be exposed via the new
interface, by doing on-the-fly (re)chunking/ingestion.

Most likely, there will be multiple implementations of store, some storing
things locally, some exposing a "remote view".

A few existing ones that come to mind are:

- Local store
- SFTP/ GCP / S3 / HTTP
- NAR/NARInfo protocol: HTTP, S3

A remote Snix store can be connected by simply connecting to its gRPC
interface, possibly using SSH tunneling, but there doesn't need to be an
additional "wire format" like the Nix `ssh(+ng)://` protocol.

Settling on one interface allows composition of stores, meaning it becomes
possible to express substitution from remote caches as a proxy layer.

It's also possible to use the existing FUSE implementation pointed to the gRPC
client interface (potentially with a caching layer in between),
exposing a lazily-substituting /nix/store mountpoint.
Using this in remote build context dramatically reduces the amount of data
transferred to a builder, as only the files really accessed during the build
are substituted.
