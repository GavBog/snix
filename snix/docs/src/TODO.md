# TODO

This contains a rough collection of ideas on the TODO list, trying to keep track
of it somewhere.

It's in process of being migrated to the
[Issue Tracker](https://git.snix.dev/snix/snix/issues) and documentation.
Please add future ideas to the issue tracker only.

Before picking something from there to work on, ask in `#snix` to make
sure noone is working on this, or has some specific design in mind already.

## Correctness > Performance
A lot of the Nix behaviour isn't well documented out, and before going too deep
into performance optimizations, we need to ensure we properly grasped all hidden
features. This is to avoid doing a lot of "overall architecture perf-related
work" and increased code complexity based on a mental model that might get
disproved later on, as we work towards correctness.

We do this by evaluating more and more parts of the official Nix test suite, as
well as our own Tvix test suite, and compare it with Nix' output.

Additionally, we evaluate attributes from nixpkgs, compare calculated output
paths (to determine equivalence of evaluated A-Terms) and fix differences as we
encounter them.

This currently is a very manual and time-consuming process, both in terms of
setup, as well as spotting the source of the differences (and "compensating" for
the resulting diff noise on resulting mismtaches).

 - We could use some better tooling that periodically evaluates nixpkgs, and
   compares the output paths with the ones produced by Nix
 - We could use some better tooling that can spot the (real) differences between
   two (graphs of) derivations, while removing all resulting noise from the diff
in resulting store paths.


## Documentation
Extend the other pages in here. Some ideas on what should be tackled:
 - Document what Tvix is, and what it is not yet. What it is now, what it is not
   (yet), explaining some of the architectural choices (castore, more hermetic
   `Build` repr), while still being compatible. Explain how it's possible to
   plug in other frontends, and use `tvix-{[ca]store,build}` without Nixlang even.
   And how `nix-compat` is a useful crate for all sorts of formats and data
   types of Nix.
 - Update the Architecture diagram to model the current state of things.
   There's no gRPC between Coordinator and Evaluator.
 - Add a dedicated section/page explaining the separation between tvix-glue and
   tvix-eval, and how more annoying builtins get injected into tvix-eval through
   tvix-glue.
   Maybe restructure to only explain the component structure potentially
   crossing process boundaries (those with gRPC), and make the rest more crate
   and trait-focused?
 - Restructure docs on castore vs store, this seems to be duplicated a bit and
   is probably still not too clear.
 - Absorb the rest of //snix/website into this.
