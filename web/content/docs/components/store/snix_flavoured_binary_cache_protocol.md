---
title: "Snix-flavoured Nix Binary Cache Protocol"
summary: ""
date: 2025-08-30T10:16:37+00:00
lastmod: 2025-08-30T10:16:37+00:00
draft: false
weight: 41
toc: true
---

{{< callout context="caution" title="Caution" icon="outline/alert-triangle" >}}
This document is a work in progress. `nar-bridge` already sends NAR URLs like
this, but the client code to make use of these hints is still missing.
{{</callout>}}

This document describes an extension of the Nix HTTP Binary Cache to allow more
granular, `snix-castore`-based substitution.

While still being fully compatible with a not Snix-aware client (like Nix
itself), it allows clients aware of this protocol extension a "shortcut", where
they parse the "castore node hint" in the NAR URL and opportunistically try to
download (only the missing) castore nodes directly.

This can improve substitution performance by a lot, as only parts of store paths
that were changed need to be downloaded.

It does not (yet) allow partial/lazy substitution, as there's no new signature
mechanism signing more data.

The client still has to have all contents of the store path available (to
calculate the NAR hash and compare with what was written and signed in the
NARInfo). It however is able to skip over parts it already has downloaded
previously.

As similar store paths (for example different versions of the same application)
share a lot of data, and local NAR hash calculation is much faster than
downloading entire store path contents all over again (especially in locations
with little network bandwidth), this should still expose significant speedups.

{{< callout context="note" title="Note" icon="outline/info-circle" >}}
A new signature mechanism including the castore root node would allow entirely
partial/lazy substitution. This is however out of scope for this document.

Defining a plain HTTP protocol to download castore nodes, blobs and chunks from
the same HTTP endpoint is also out of scope for this document.
{{</callout>}}

## NARInfo
For each Store Path, Nix requests a `$outhash.narinfo` file.

It is a text-based format, containing metadata about a store path.

The Snix-flavoured Nix Binary Cache Protocol:
 - sets `Compression: none`
 - omits `FileHash` / `FileSize` (which are ignored anyways)
 - encodes the castore root node in the NAR `URL` itself (described further
   below)

Snix-unaware clients (like Nix) can substitute this just fine. They can even
make use of content negotiation to still download with compression (which is
what `nar-bridge` uses to still send NARs in compressed fashion).

## castore-infused NAR URL
While Nix usually produces NARInfo files with
`nar/$filehash.nar[.$compressionSuffix]` as `URL` field, the field can be any
valid (relative) URL.

We can use this to encode additional metadata in a non-invasive fashion.

A "Snix-flavoured Nix Binary Cache" sends NAR URLs in its NARInfo files using
this pattern:

`nar/snix-castore/$castore-root-node?narsize=$nar_size`

`$castore-root-node` is replaced with the urlsafe base64-encoded protobuf
representation of the castore root node (with omitted name field) representing
the store path contents.

`$nar_size` is used to signal the total NAR length. [^nar-size]

## NAR-{rendering,ingesting} Backends
Using these kind of NAR URLs allows a backend to assemble NARs on the fly from
only castore storage, without having to maintain any context / information about
store paths. This makes it a good candidate to run separately.

Only the write path (assuming HTTP PUT from a Nix client) needs to internally
maintain a mapping from (recent) NAR hashes to the castore node calculated while
receiving the NAR payload (to replace the NAR url sent by the client with the
castore-infused NAR one).

This is implemented in nar-bridge, both the read path (with ranging), as well as
the write path.

## Client upgrade
After verifying signatures, and upon detection of above-mentioned
`nar/snix-castore/…` URLs in the NARInfo, clients MAY instead use the following
substitution strategy:

### Parsing phase
Parse the `$castore-root-node` part of the URL, ensure it's a valid castore Node
(without a name).

### Fetching phase
 - If the node encodes a valid (but locally unknown) directory node, fetch it
   (and all its children), validating their hashes and connectivity.
   Then fetch all (locally unknown) blobs in any file nodes.
 - If the node encodes a valid (but locally unknown) file node, fetch it.
 - If the node encodes a valid symlink node, continue.

Due to the content-addressed nature of castore, fetching of the contents
can happen with any castore nodes known to the client.

### NAR Calculation phase
Now all contents are available locally, but to ensure the (partial) substitution
based on a unsigned castore node pointer actually produces the same NAR
contents for which the signature was made, clients MUST once calculate the NAR
hash and size for the substituted castore node, and check it matches the NAR
hash and size listed in the NARInfo [^nar-calc].

### Resiliency
If any of these steps fails, clients MUST fall back to download the
`nar/snix-castore/…` URL mentioned in the NARInfo "using the conventional way",
by simply fetching the URL as-is, and reading the NAR.
A warning may be logged, but such an issue MUST NOT be fatal.

Clients might decide to temporarily not try upgrading to snix-castore-based
substitution for other store paths from the same binary cache.

---
[^nar-size]: For non-range queries to NARs, this avoids fetching the directory
             closure to calculate the NAR size, we can simply echo back this
             value to the client, as a `Content-Length` header.
             If the client modified the parameter before sending the request, it
             won't cause harm on the server side.
[^nar-calc]: The calculation of the NAR hash can obviously already start during
             the fetching phase, though it might make sense to fetch less
             "linear" as in the NAR.
