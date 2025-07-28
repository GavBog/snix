{ pkgs, lib, ... }:

pkgs.buildGoModule {
  name = "gerrit-webhook-to-irccat";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./main.go
      ./go.mod
      ./go.sum
    ];
  };
  vendorHash = "sha256-i7EpH9/2FGZwhn4VHP32aL13M07fd+cbUhzddYi5XfE=";
}
