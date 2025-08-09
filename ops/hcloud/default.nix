{
  depot,
  lib,
  pkgs,
  ...
}:

depot.nix.readTree.drvTargets rec {
  terraform = pkgs.terraform.withPlugins (p: [
    p.hcloud
  ]);

  validate = depot.tools.checks.validateTerraform {
    inherit terraform;
    name = "hcloud";
    src = lib.cleanSource ./.;
  };
}
