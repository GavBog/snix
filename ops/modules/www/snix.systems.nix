{ depot, ... }:

{
  imports = [
    ./base.nix
  ];

  config = {
    services.nginx.virtualHosts."snix.systems" = {
      enableACME = true;
      forceSSL = true;
      root = depot.fun.snix-solves-this;
    };
  };
}
