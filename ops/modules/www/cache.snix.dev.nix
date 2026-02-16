{
  imports = [
    ./base.nix
  ];

  services.nginx.virtualHosts."cache.snix.dev" = {
    forceSSL = true;
    enableACME = true;
    locations."/".proxyPass = "http://build03.infra.snix.dev:5000";
  };
}
