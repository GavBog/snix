# This program is used as a Gerrit hook to trigger builds on
# Buildkite and perform other maintenance tasks.
{ pkgs, ... }@args:

let
  inherit (pkgs) lib;
in

pkgs.buildGoModule {
  name = "besadii";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./main.go
      ./go.mod
    ];
  };
  # No third party dependencies
  vendorHash = null;
}
