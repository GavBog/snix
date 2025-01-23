Evaluating the Nix programming language, used by the Nix package
manager, is currently very slow. This becomes apparent in all projects
written in Nix that are not just simple package definitions, for
example:

* the NixOS module system
* TVL projects like
  [`//nix/yants`](https://at.tvl.fyi/?q=%2F%2Fnix%2Fyants) and
  [`//web/bubblegum`](https://at.tvl.fyi/?q=%2F%2Fweb%2Fbubblegum).
* the code that [generates build
  instructions](https://at.tvl.fyi/?q=%2F%2Fops%2Fpipelines) for TVL's
  [CI setup](https://tvl.fyi/builds)

Whichever project you pick, they all suffer from issues with the
language implementation. At TVL, it takes us close to a minute to
create the CI instructions for our monorepo at the moment - despite it
being a plain Nix evaluation. Running our Nix-native build systems for
[Go](https://code.tvl.fyi/about/nix/buildGo) and [Common
Lisp](https://code.tvl.fyi/about/nix/buildLisp) takes much more time
than we would like.

Some time last year a few of us got together and started investigating
ways to modernise the current architecture of Nix and figure out how
to improve the speed of some of the components. We created over [250
commits](https://cl.tvl.fyi/q/topic:tvix) in our fork of the Nix 2.3
codebase at the time, tried [performance
experiments](https://cl.tvl.fyi/c/depot/+/1123/) aimed at improving
the current evaluator and fought [gnarly
bugs](https://cl.tvl.fyi/c/depot/+/1504).

After a while we realised that we were treading water: Some of our
ideas are too architecturally divergent from Nix to be done on top of
the existing codebase, and the memory model of Nix causes significant
headaches when trying to do any kind of larger change.

We needed an alternative approach and started brainstorming on a bent
whiteboard in a small flat in Hurghada, Egypt.

![flokli & tazjin brainstorming](https://static.tvl.fyi/latest/files/flokli_tazjin_tvix.webp)

Half a year later we are now ready to announce our new project:
**Tvix**, a re-imagined Nix with full nixpkgs compatibility. Tvix is
generously funded [by NLNet](https://nlnet.nl/project/Tvix/) (thanks!)
and we are ready to start implementing it.

The [Tvix
architecture](https://code.tvl.fyi/about/tvix/docs/components.md) is
designed to be modular: It should be possible to write an evaluator
that plugs in the Guile language (for compatibility with GNU Guix), to
use arbitrary builders, and to replace the store implementation.

Tvix has these high-level goals:

* Creating an alternative implementation of Nix that is **fully
  compatible with nixpkgs**.

  The package collection is an enormous effort with hundreds of
  thousands of commits, encoding expert knowledge about lots of
  different software and ways of building and managing it. It is a
  very valuable piece of software and we must be able to reuse it.

* More efficient Nix language evaluation, leading to greatly increased
  performance.

* No more strict separation of evaluation and build phases: Generating
  Nix data structures from build artefacts ("IFD") should be supported
  first-class and not incur significant performance cost.

* Well-defined interaction protocols for how the three different
  components (evaluator, builder, store) interact.

* A builder implementation using OCI instead of custom sandboxing
  code.

![adisbladis & tazjin brainstorming](https://static.tvl.fyi/latest/files/adisbladis_tazjin_tvix.webp)

Tvix is not intended to *replace* Nix, instead we want to improve the
ecosystem by offering an alternative, fast and reliable implementation
for Nix features that are in use today.

As things ramp up we will be posting more information on this blog,
for now you can keep an eye on
[`//tvix`](https://code.tvl.fyi/tree/tvix) in the TVL monorepo
and subscribe to [our feed](https://tvl.fyi/feed.atom).

Stay tuned!

<span style="font-size: small;">PS: TVL is international, but a lot of
the development will take place in our office in Moscow. Say hi if
you're around and interested!</span>
