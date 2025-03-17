#! /usr/bin/env bash
# SPDX-FileCopyrightText: edef <edef@edef.eu>
# SPDX-License-Identifier: CC0-1.0
set -euo pipefail

drv=$(nix-instantiate '<nixpkgs>' -A ghc)
nix --extra-experimental-features nix-command show-derivation -r "$drv" | jq -r '.[] | .outputs[].path, .inputSrcs[]' | sort -u | cut -d/ -f4 | cut -d- -f1 > maxrefs
nix-store --dump "$(nix-build "$drv")" > nar
