{ ... }:

{
  imports = [
    ./base.nix
  ];

  config = {
    services.nginx = {
      enable = true;
      upstreams.grafana.servers."unix:/run/grafana/web.sock" = { };
      virtualHosts."status.snix.dev" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://grafana/";
          proxyWebsockets = true;
        };
      };
    };
  };
}
