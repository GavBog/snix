{ config, ... }:

{
  imports = [
    ./base.nix
  ];

  config = {
    services.nginx =
      let
        scfg = config.services.grafana.settings.server;
      in
      {
        enable = true;
        virtualHosts."${scfg.domain}" = {
          enableACME = true;
          forceSSL = true;
          locations."/" = {
            proxyPass = "http://${scfg.http_addr}:${toString scfg.http_port}";
            proxyWebsockets = true;
          };
        };
      };
  };
}
