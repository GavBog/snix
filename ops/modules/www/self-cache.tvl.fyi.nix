# per-host addresses for publicly reachable caches, for use with builderball
# TODO(tazjin): merge with the public cache module; but needs ACME fixes
{ config, lib, ... }:

{
  imports = [
    ./base.nix
  ];

  config = lib.mkIf config.services.depot.harmonia.enable {
    services.nginx.virtualHosts."${config.networking.hostName}.cache.tvl.fyi" = {
      enableACME = true;
      forceSSL = true;

      extraConfig = ''
        location = /cache-key.pub {
          alias /run/agenix/nix-cache-pub;
        }

        location / {
          proxy_pass http://${config.services.depot.harmonia.settings.bind};
        }
      '';
    };
  };
}
