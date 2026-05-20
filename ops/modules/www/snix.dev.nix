{ depot, ... }:

{
  imports = [
    ./base.nix
  ];

  config = {
    services.nginx.virtualHosts."snix.dev" = {
      enableACME = true;
      forceSSL = true;
      root = depot.web.website;

      locations."/rustdoc/".alias = "${depot.snix.rust-docs}/share/doc/";
    };
  };
}
