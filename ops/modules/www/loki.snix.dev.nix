{ config, ... }:
{
  imports = [
    ./base.nix
  ];

  services.nginx = {
    upstreams.loki = {
      servers."127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}" = { };
      extraConfig = "keepalive 16;";
    };

    virtualHosts."loki.snix.dev" = {
      enableACME = true;
      forceSSL = true;
      locations."/loki/api/v1/push" = {
        proxyPass = "http://loki";
        basicAuthFile = config.age.secrets.metrics-push-htpasswd.path;
      };
    };
  };
}
