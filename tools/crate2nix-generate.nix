{ pkgs, depot, ... }:

# Regenerate Cargo.lock in current directory, then run crate2nix generate, then
# format the generated file with depotfmt.
pkgs.writeShellScriptBin "crate2nix-generate" ''
  export PATH="${
    pkgs.lib.makeBinPath [
      pkgs.jq
      pkgs.crate2nix
      pkgs.findutils
      pkgs.cargo
      depot.tools.depotfmt
    ]
  }:$PATH"

  cargo metadata --offline --no-deps --format-version 1 | jq -r '.packages[] | .id' | xargs cargo update --offline
  crate2nix generate --all-features
  depotfmt --no-cache Cargo.nix
''
