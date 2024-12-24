{ pkgs, depot, ... }:

let
  inherit (depot.users.sterni.nix.html)
    __findFile
    ;
in

{
  imports = [
    ./nginx.nix
  ];

  config = {
    services.nginx.virtualHosts."sterni.lv" = {
      enableACME = true;
      forceSSL = true;
      root = pkgs.writeTextFile {
        name = "sterni.lv-http-root";
        destination = "/index.html";
        text = <html> { } [
          (<head> { } [
            (<meta> { charset = "utf-8"; } null)
            (<title> { } "no thoughts")
          ])
          (<body> { } "🦩")
        ];
      };
      # TODO(sterni): tmp.sterni.lv
      locations."/tmp/".root = toString /srv/http;
    };
  };
}
