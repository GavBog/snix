{ depot, ... }:

depot.third_party.crane.lib.cargoTest (
  depot.snix.commonCraneArgs
  // {
    name = "nix-compat-derive-tests";
    inherit (depot.snix) cargoArtifacts;
    cargoTestExtraArgs = "-p nix-compat-derive-tests";
  }
)
