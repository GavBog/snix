---
title: "Using Snix as Lower Nix Overlay Store"
description: "Using Snix as Lower Nix Store"
date: 2025-03-21T22:40:33+00:00
lastmod: 2025-03-21T22:40:33+00:00
draft: false
weight: 51
categories: []
tags: []
contributors: []
pinned: false
homepage: false
---

## Background

About a year ago, nix introduced a new experimental store type:
[Local Overlay Store]. This store allows having multiple physical stores acting
as a single logical store.

With this approach, stores are layered on top of each other with all but the
top-most layer being writable, the others are read-only. The feature is
described in the [Upstream Nix Documentation][Local Overlay Store]. Work is
[ongoing][lix-local-overlay] to bring the feature to Lix aswell.

The main use-case is for it is having a large nix store mounted onto a machine
as read-only and configure nix to use data stored in it to avoid
rebuilding/substituting from `cache.nixos.org`.

Due to implementation details of this feature, the lower layer(s) can not only
be a location on the file system but also have another `nix-daemon` back the
lower layer(s).

## Meet the new `snix` nix-daemon

Implementing `nix-daemon` protocol is a lot of effort, due to being entirely
custom and undocumented. On the other hand, mounting a large nix store is a
great fit for `snix` as our [content-addressed store][castore] is much more
space efficient than conventional filesystem storage. A great example of this
can be found [here][replit].

What's interesting about Local Overlay Store, is that it uses only a small
subset of operations when talking to the `nix-daemon`. And this seemed like a
good opportunity to make using `nix` backed by our `castore` more seamless.

So we are happy to announce that as of today, `snix` has implemented **all** of
the operations required to operate as a lower layer in nix's overlay store.

Check out our [Guide]({{\< ref "/docs/guides/local-overlay" >}}) on how to set
it up.

Please test it out, let us know what you think and report [bugs].

## What's next for Local Overlay Store

We have plans expand our `nix-daemon` to support non-readonly mode and have all
possible substitutions go into your local `castore` and only use the upper nix
store for local builds.

We also want to make `snix` nix-daemon easier to use without having to run
multiple `snix` components.

Stay tuned.

[castore]: https://snix.dev/docs/components/overview/
[bugs]: https://git.snix.dev/snix/snix/issues
[Local Overlay Store]: https://nix.dev/manual/nix/2.26/store/types/experimental-local-overlay-store.html
[replit]: https://blog.replit.com/tvix-store
[lix-local-overlay]: https://gerrit.lix.systems/c/lix/+/2859
