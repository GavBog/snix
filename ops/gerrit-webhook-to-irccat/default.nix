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
  vendorHash = "sha256-Xq0p6EEPFS23H+RMkzQw6767d8WujAz7doR6E/YKrgY=";
}
