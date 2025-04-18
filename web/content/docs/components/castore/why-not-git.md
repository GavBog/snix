---
title: "Why not Git?"
summary: ""
date: 2025-04-04T16:16:37+00:00
lastmod: 2025-04-04T16:16:37+00:00
draft: false
weight: 42
toc: false
---

We've been experimenting with (some variations of) the git tree and object
format, and ultimately decided against using it as an internal format, and
instead adapted our own [Data Model][castore-data-model].

While castore shares some similarities with the format used in git for trees and
objects, the git one has shown some significant disadvantages:

### The binary encoding itself

#### git trees
The git tree object format is a very binary, error-prone and
"made-to-be-read-and-written-from-C" format.

Tree objects are a combination of null-terminated strings, and fields of known
length. References to other tree objects use the literal sha1 hash of another
tree object in this encoding.
Extensions of the format/changes are very hard to do right, because parsers are
not aware they might be parsing something different.

The [Snix Castore Data Model][castore-data-model] uses a canonical protobuf
serialization, and uses the [BLAKE3][] hash of that serialization to point
to other `Directory` messages.
It's both compact and with a wide range of libraries for encoders and decoders
in many programming languages.
The choice of protobuf makes it easy to add new fields, and make old clients
aware of some unknown fields being detected [^adding-fields].

#### git blob
On disk, git blob objects start with a "blob" prefix, then the size of the
payload, and then the data itself. The hash of a blob is the literal sha1sum
over all of this - which makes it something very git specific to request for.

The [Snix Castore Data Model][castore-data-model] simply uses the
[BLAKE3][] hash of the literal contents when referring to a file/blob,
which makes it very easy to ask other data sources for the same data, as no
git-specific payload is included in the hash.
This also plays very well together with things like [iroh][iroh-discussion],
which plans to provide a way to substitute (large)blobs by their [BLAKE3][] hash
over the IPFS network.

In addition to that, [BLAKE3][] makes it possible to do
[verified streaming][bao], as already described in other parts of the
documentation.

The git tree object format uses sha1 both for references to other trees and
hashes of blobs, which isn't really a hash function to fundamentally base
everything on in 2023.
The [migration to sha256][git-sha256] also has been dead for some years now,
and it's unclear what a "[BLAKE3][]" version of this would even look like.

[bao]: https://github.com/oconnor663/bao
[BLAKE3]: https://github.com/BLAKE3-team/BLAKE3
[castore-data-model]: {{< relref "data-model.md" >}}
[git-sha256]: https://git-scm.com/docs/hash-function-transition/
[iroh-discussion]: https://github.com/n0-computer/iroh/discussions/707#discussioncomment-5070197
[^adding-fields]: Obviously, adding new fields will change hashes, but it's something that's easy to detect.
