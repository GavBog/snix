{
  depot,
  pkgs,
  lib,
  ...
}:
depot.snix.cli.make-cli {
  pname = "default";
  paths = [
    depot.snix.cli.derivation-show
    depot.snix.cli.eval
    depot.snix.cli.nar-bridge
    depot.snix.build
    depot.snix.castore
    depot.snix.castore-http
    depot.snix.nix-daemon
    depot.snix.store
  ];
  base = depot.snix.cli.base;
}
