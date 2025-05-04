---
title: "Protocol"
slug: protocol
description: ""
summary: ""
date: 2025-03-14T14:14:35+01:00
lastmod: 2025-03-14T14:14:35+01:00
draft: false
weight: 41
toc: true
---

## Standardized Interface
One goal is to make the build protocol a standardized interface, allowing to
make the sandboxing mechanism used by the build process pluggable.

Nix is currently using a hard-coded [libseccomp][] based sandboxing mechanism
and another one based on [sandboxd][] on macOS.
These are only separated by [compiler preprocessor macros][ifdef] within the same
source files despite having very little in common with each other.

In Snix, the Builders need to implement a trait, and there are multiple
implementations. In addition to an [OCI][] builder and plans for
more[^other-builders], we currently include a gRPC client (and server adapter),
allowing to run the builder both locally or remotely, or plug in your entirely
separate Builder, as long as it speaks the same gRPC protocol.

Check `build/protos/build.proto` for a detailed description of the protocol,
individual fields, and the tests in `glue/src/tvix_build.rs` for some examples.

While we're somewhat confident about the `BuildRequest`, the RPC method itself
will change to a stream of events, so we can stream logs/build telemetry to the
requesting client.

## Unaware of Nix sandbox internals

The environment in which builds currently happen is currently very Nix-specific.
In Snix, we don't want to maintain all the intricacies of a Nix-specific
sandboxing environment in every builder, and instead only provide a more
generic interface, receiving more generic build requests (and translate
Derivations into this format). [^reapi]

Another goal of the builder protocol is to not be too tied to the Nix
implementation itself, allowing it to be used for other builds/workloads in the
future (and experimenting with different hashing schemes etc without having to
change builder code).



In concrete terms, this means the builder protocol is versatile enough to
express the environment a Nix build sets up, while it itself is not aware of
"what any of this means".

For example, it is not aware of how certain environment variables are set in a
nix build, but provides the necessary infrastructure to specify environment
variables that should be set.

It's also not aware of what nix store paths are. Instead, it allows:

 - specifying a list of paths expected to be produced during the build
 - specifying a list of castore root nodes to be present in a specified
   `inputs_dir`.
 - specifying which paths are write-able during build.

In case all specified paths are produced, and the command specified in
`command_args` succeeds, the build is considered to be successful.

This happens to be sufficient to *also* express how Nix builds works.

## More hermetic builds, Build Provenance
Nix uses derivations (encoded in ATerm) as nodes in its build graph, but it
refers to other store paths used in that build by these store paths only. As
mentioned before, store paths only address the inputs - and not the content.

This poses a big problem in Nix as soon as builds are scheduled on remote
builders: There is no guarantee that files at the same store path on the remote
builder actually have the same contents as on the machine orchestrating the
build. If a package is not binary reproducible, this can lead to so-called
[frankenbuilds].

This also introduces a dependency on the state that's present on the remote
builder machine: Whatever is in its store and matches the paths will be used,
even if it was maliciously placed there.

To eliminate this hermiticity problem and increase the integrity of builds,
we've decided to use content-addressing in the builder protocol.

In the long run, recording this information is gonna improve our posture
regarding [Build Provenance][slsa-provenance].


[OCI]:             https://github.com/opencontainers/runtime-spec
[libseccomp]:      https://github.com/seccomp/libseccomp
[sandboxd]:        https://www.unix.com/man-page/mojave/8/sandboxd/
[ifdef]:           https://gcc.gnu.org/onlinedocs/cpp/Ifdef.html
[frankenbuilds]:   https://blog.layus.be/posts/2021-06-25-frankenbuilds.html
[slsa-provenance]: https://slsa.dev/spec/v1.0/provenance

[^other-builders]: With a well-defined builder abstraction, it's also easy to imagine
                   other backends such as a Kubernetes-based / bwrap / gVisor /
                   Cloud Hypervisor in the future.
[^reapi]: There have already been some discussions in the Nix community, to switch
  to REAPI:
  https://discourse.nixos.org/t/a-proposal-for-replacing-the-nix-worker-protocol/20926/22
