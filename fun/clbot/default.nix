{ pkgs, ... }@args:

let
  inherit (pkgs) lib;
in

pkgs.buildGoModule {
  name = "clbot";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./clbot.go
      ./clbot_test.go
      ./go.mod
      ./go.sum
      ./backoffutil
      ./gerrit
    ];
  };
  vendorHash =
    # Assert the expected go.sum hash matches so we don't forget to update the FOD hash on dependency changes.
    assert builtins.hashFile "sha256" ./go.sum
      == "f999a34979af2113b867446a445a4d8c066d68f945cd4470fe33fe4fead6d15b";
    "sha256-IvFg+/lwBsJiJoLCRP5KU5+tRuHDLpwWHHkmt67yJd8=";
}
