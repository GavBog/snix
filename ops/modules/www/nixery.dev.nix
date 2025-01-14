{ config, ... }:

{
  imports = [
    ./base.nix
  ];

  config = {
    services.nginx.virtualHosts."nixery.dev" = {
      serverName = "nixery.dev";
      enableACME = true;
      forceSSL = true;

      extraConfig = ''
        location / {
          proxy_pass http://localhost:${toString config.services.depot.nixery.port};
        }
      '';
    };
  };
}
