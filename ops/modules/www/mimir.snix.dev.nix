{ config, ... }:
let
  mimirPort = config.services.mimir.configuration.server.http_listen_port;
in
{
  imports = [
    ./base.nix
  ];
  services.nginx = {
    upstreams.mimir = {
      servers."127.0.0.1:${toString mimirPort}" = { };
      extraConfig = "keepalive 16;";
    };

    virtualHosts."mimir.snix.dev" = {
      enableACME = true;
      forceSSL = true;
      locations."/api/v1/push" = {
        proxyPass = "http://mimir";
        basicAuthFile = config.age.secrets.metrics-push-htpasswd.path;
      };
    };
  };
}
