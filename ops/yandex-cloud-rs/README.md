yandex-cloud-rs
===============

Client library for Yandex Cloud gRPC APIs, as published in their
[GitHub repository][repo].

Please see the [online documentation][docs] for user-facing
information, this README is intended for library developers.

The source code of the library lives [in the TVL repository][code].

-------------

In order to build this library, the gRPC API definitions need to be
fetched from GitHub. By default this is done by Nix (see
`default.nix`), which then injects the location of the API definitions
through the `YANDEX_CLOUD_PROTOS` environment variable.

The actual code generation happens through the calls in `build.rs`.

Releases of this library are done from *dirty* trees, meaning that the
version on crates.io should already contain all the generated code. In
order to do this, after bumping the version in `Cargo.toml` and the
API commit in `default.nix`, the following release procedure should be
used:

```
# Get rid of all generated source files
find src | grep '.rs$' | grep -v '^src/lib.rs$' | xargs rm

# Get rid of all old artefacts
cargo clean

# Verify that a clean build works as intended
cargo build

# Verify that all documentation builds, and verify that it looks fine:
#
# - Is the version correct (current date)?
# - Are all the services included (i.e. not an accidental empty build)?
cargo doc --open

# If everything looks fine, release:
cargo publish --allow-dirty
```

[repo]: https://github.com/yandex-cloud/cloudapi
[docs]: https://docs.rs/yandex-cloud/latest/yandex_cloud/
[code]: https://code.tvl.fyi/tree/ops/yandex-cloud-rs
