{ pkgs, lib, ... }:

pkgs.buildGoModule {
  name = "buildkite-api-proxy";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./main.go
      ./go.mod
      ./go.sum
    ];
  };
  vendorHash = "sha256-YtLQYW1W+i9Zkw01kZf/xxJd1X5ttIutqlRpHNWvp4Y=";
}
