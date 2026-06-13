# Nix Language Test Suite

## What Issues It Addresses

Primarily from these:

- [nix-lang-test-suite/README.md](../../snix/nix-lang-test-suite/README.md)

- [https://git.snix.dev/snix/snix/issues/64](https://git.snix.dev/snix/snix/issues/64)

## Core Idea

Each test case consists of three files: `.nix`, `.kdl` and `.{exp,err}`

`.nix` file provides the nix expression similarly to how tests are described now

`.kdl` file describes the requirements for the case.

`.exp` or `.err` file contains the expected output or error code. Only one of these files must be present.

Each `.kdl` consists of 3 optional sections:

- lang - language parts required for the test
- environment - the surrounding environment e.g. files, variables
- runtime_opts - runtime flags needed for the test e.g. strictness, search path. Those do not map into CppNix flags though. For example, `flakes` are defined in the `lang` section, not here

To learn a bit more about `.kdl` format, see [meta.kdl](./tests/meta.kdl)

Filenames have no meaning and runners ignore them. "eval-okay"-like names are kept to distinguish between existing and new cases added for this proposal.

At the moment, test cases are split by groups requiring different test suite features like defining builtins, environment, or something else. The proper organization by categories should be discussed.

## How It Addresses Current Issues

> It should work with potentially any Nix implementation and with all serious
> currently available ones (C++ Nix, Lix, hnix, Snix, …)

Having language-agnostic case descriptions potentially allows every Nix implementation to set up their own runners/environments. What's important here is to keep cases precise.

> It should be easy to add test cases, independent of any specific
> implementation.

As long as the test case fits into the existing test suite, it is easy: add .nix + .kdl + .exp + update test metadata if needed.

> It should be simple to ignore test cases and mark know failures
> (similar to the notyetpassing mechanism in the Snix test suite).

This is a problem of runners rather than the test suite, but as long as the suite provides enough information, marking known failures should not be a big problem. The reference runners still execute skipped cases and only ignore mismatching results. If a skipped case starts matching the expected result, the runner fails so the case can be removed from `skip.toml`.

> **Filesystem**: Some test cases `import` other files or use `builtins.readFile`, `builtins.readDir` and friends.

Files required for the test case are defined in the `environment` section. See [./tests/cases/environment/eval-okay-readFileType.kdl] as an example.

## Decisions Made

### Why KDL

Because TOML is bad with nesting, which does not play well with tree-like fixture descriptions.

Because YAML seems too verbose and JSON seems less human-readable

Because KDL is human-readable and thanks to its tree-like structure it provides nice ergonomics for nesting and fixtures

### .nix + .kdl Files For Better Debugging

One thought was to place input expressions in the .kdl file, like, for example, [test262](https://github.com/tc39/test262) does.

But it is convenient during development to be able to run `nix-instantiate --eval <path-to.nix>` and see the output. The downside is that not all cases can be run this way, but it's okay since there are multiple cases that can't be verified this way either (e.g. search path related).

### Runners Aware of Test Suite But Not Vice-Versa

Even within this project there are 2 runners - Cpp and Nix - each requiring its own config and skipping logic. For that reason, the test suite only provides test descriptions and it's up to runners how to deal with them. That means, for example, that the suite does not explicitly declare things like the Nix version in which a feature was introduced.

This separation also makes the test cases suitable for a repository shared by multiple implementations.

## About Runners

### Why

These are a minimal implementations to test the idea and see if the format is nice to work with.

The tests are just cargo tests. You can either run them by building the crate with Nix (which runs the tests), or by invoking `cargo test` manually:

```sh
# snix
mg build //contrib/nix-language-test-suite/src:snix

# or impure by invoking `cargo test`:
cargo test --package=nix-language-test-suite-cppnix --manifest-path=contrib/nix-language-test-suite/src/Cargo.toml

# cppnix
mg build //contrib/nix-language-test-suite/src/cppnix:nix_2_3
mg build //contrib/nix-language-test-suite/src/cppnix:nix_latest_verified
mg build //contrib/nix-language-test-suite/src/cppnix:lix_latest

# or impure by invoking `cargo test`:
NIX_VERSION=lix-2.94.2 cargo test --package=nix-language-test-suite-cppnix --manifest-path=contrib/nix-language-test-suite/src/Cargo.toml
# This still times out for some test cases, so you might want to filter
# which tests to run by passing a substring as an additional argument.
```

### Snix Runner

In this example, the evaluator is built with the store because it might cover more cases. If needed (and likely helpful), different evaluators can be built.

### C++ Nix Runner

This one builds a `nix-instantiate` command and runs it. The config's format is not set in stone, just a first thought I had on my mind

## Thoughts On This Proposal

This proposal is a small step forward and at the moment its biggest benifit is that it unifies and puts together existing test cases: eval, glue, [nix_oracle](https://git.snix.dev/snix/snix/src/commit/da9a2be3faa96e79185625a225000fdefabdfa51/snix/eval/tests/nix_oracle.rs) and verify-lang-tests and adds error comparison

My concern is what might be the limits of this approach. What if certain behaviour can only be verified via multiple actions and won't feed into `input -> eval -> output` model? An example of such cases can be something like CppNix's tests here: https://github.com/NixOS/nix/tree/master/tests/nixos
