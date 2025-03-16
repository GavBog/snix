{ depot, ... }:

{
  imports = [
    ./base.nix
  ];

  config = {
    services.nginx.virtualHosts."bolt.snix.dev" = {
      root = depot.contrib.snixbolt;
      enableACME = true;
      forceSSL = true;
    };
  };
}
