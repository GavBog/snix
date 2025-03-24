{
  imports = [
    ./base.nix
  ];

  services.nginx.virtualHosts."cache.snix.dev" = {
    forceSSL = true;
    enableACME = true;
    locations."/".proxyPass = "http://build01.infra.snix.dev:5000";
  };
}
