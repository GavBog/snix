{
  depot,
  pkgs,
  lib,
  ...
}: # readTree options
{ config, ... }: # passed by module system

let
  srvos = import (
    builtins.fetchTarball {
      url = "https://github.com/nix-community/srvos/archive/8e7d3c690975ee6790926bdfd1258016c967d163.tar.gz";
      sha256 = "sha256-l7epHqAcg8Qktu8vO2ZfjSH1wcai01XQOKQA9ADHIk4=";
    }
  );
  disko = (
    builtins.fetchTarball {
      url = "https://github.com/nix-community/disko/archive/84dd8eea9a06006d42b8af7cfd4fda4cf334db81.tar.gz";
      sha256 = "13mfnjnjp21wms4mw35ar019775qgy3fnjc59zrpnqbkfmzyvv02";
    }
  );

in
{
  imports = [
    "${disko}/module.nix"
    ./disko.nix
    ./monitoring.nix
    ./nar-bridge.nix
    srvos.nixosModules.hardware-hetzner-online-amd
    srvos.nixosModules.mixins-nginx
  ];

  options = {
    machine.domain = lib.mkOption {
      type = lib.types.str;
      default = "nixos.snix.store";
    };
  };

  config = {
    services.nginx.virtualHosts."${config.machine.domain}" = {
      enableACME = true;
      forceSSL = true;
    };

    security.acme.acceptTerms = true;
    security.acme.defaults.email = "admin+acme@numtide.com";

    nixpkgs.hostPlatform = lib.mkForce "x86_64-linux";

    # kept as-is because we don't want to relabel historical metrics
    networking.hostName = "tvix-cache";

    systemd.network.networks."10-uplink".networkConfig.Address = "2a01:4f9:3071:1091::2/64";

    # Enable SSH and add some keys
    services.openssh.enable = true;

    users.users.root.openssh.authorizedKeys.keys =
      depot.ops.users.edef
      ++ depot.ops.users.flokli
      ++ depot.ops.users.mic92
      ++ depot.ops.users.padraic
      ++ depot.ops.users.zimbatm;

    environment.systemPackages = [
      pkgs.helix
      pkgs.htop
      pkgs.kitty.terminfo
      pkgs.tmux
    ];

    system.stateVersion = "24.11";
  };
}
