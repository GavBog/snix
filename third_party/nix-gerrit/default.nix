# This file imports the pinned nix-gerrit.

{
  depot ? { },
  ...
}:

let
  nix-gerrit-src = depot.third_party.sources.nix-gerrit;
in
import nix-gerrit-src {
  pkgs = depot.third_party.nixpkgs;
}
