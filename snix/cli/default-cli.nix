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
    depot.snix.cli.castore
    depot.snix.cli.castore-http
    depot.snix.cli.eval
    depot.snix.cli.nar-bridge
    depot.snix.cli.nix-daemon
    depot.snix.build
    depot.snix.store
  ];
  base = depot.snix.cli.base;
}
