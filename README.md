Snix is a modern Rust re-implementation of the components of the Nix package
manager.

For more information, checkout the website, hosted at
[snix.dev](https://snix.dev), which also is available in the `web/` subdirectory
of this repository.

It documents the status of this project, usage/development instructions, contact
details and much more than what would fit in here. Seriously, check it out!

# License structure
All Snix crates in this repository are licensed under GPL-3.0, with the
exception of the protocol buffer definitions used for communication between
services which are available under a more permissive license (MIT).

The idea behind this structure is that any direct usage of our code (e.g.
linking to it, embedding the evaluator, etc.) will fall under the terms of
the GPL3, but users are free to implement their own components speaking these
protocols under the terms of the MIT license.

Other tooling in this repository might be licensed differently, and is usually
described in the code itself, via some auxillary metadata (`Cargo.toml` etc), or
a `LICENSE` file in the same or parent folder(s). If this is not the case,
please open a bug!
