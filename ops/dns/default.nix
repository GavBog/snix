{ depot, lib, pkgs, ... }:

let
  checkZone = zone: file: pkgs.runCommand "${zone}-check" { } ''
    ${pkgs.bind}/bin/named-checkzone -i local ${zone} ${file} | tee $out
  '';

in
depot.nix.readTree.drvTargets rec {
  # Provide a Terraform wrapper with the right provider installed.
  terraform = pkgs.terraform.withPlugins (p: [
    p.digitalocean
  ]);

  validate = {
    snix-dev = checkZone "snix.dev" ./snix.dev.zone;
    snix-systems = checkZone "snix.systems" ./snix.systems.zone;
    terraform = depot.tools.checks.validateTerrform {
      inherit terraform;
      name = "dns";
      src = lib.cleanSource ./.;
    };
  };
}
