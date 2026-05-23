{ pkgs, depot, ... }:

# Run crate2nix-generate in each directory in the repo with a `Cargo.nix` file.
pkgs.writeShellScriptBin "crate2nix-generate-all" ''
  export PATH="${
    pkgs.lib.makeBinPath [
      pkgs.findutils
      pkgs.git
      depot.tools.crate2nix-generate
    ]
  }:$PATH"
  REPO_ROOT="''${MG_ROOT:-$(git rev-parse --show-toplevel)}"
  find "$REPO_ROOT" -name Cargo.nix -exec sh -c 'cd "$(dirname {})"; echo $PWD ; crate2nix-generate' \;
''
