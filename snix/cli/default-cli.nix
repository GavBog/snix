{
  depot,
  pkgs,
  lib,
  ...
}:
depot.snix.cli.make-cli {
  pname = "default";
  paths = [
    depot.snix.cli.eval
    depot.snix.build
    depot.snix.castore
    depot.snix.castore-http
    depot.snix.nar-bridge
    #FUTUREWORK: Add and rename depot.snix.nix-compat
    depot.snix.nix-daemon
    depot.snix.store
  ];
  base = depot.snix.cli.base;
}
