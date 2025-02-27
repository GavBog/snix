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
      root = depot.users.sterni.nix.build.website "sterni.lv" { } {
        "index.html" = { ... }: pkgs.writeText "index.html" (
          <html> { } [
            (<head> { } [
              (<meta> { charset = "utf-8"; } null)
              (<title> { } "no thoughts")
            ])
            (<body> { } "🦩")
          ]
        );
      };
      # TODO(sterni): tmp.sterni.lv
      locations."/tmp/".root = toString /srv/http;
      extraConfig = ''
        location = /robots.txt {
           add_header Content-Type text/plain;
           return 200 "User-agent: *\nDisallow: /tmp\n";
        }
      '';
    };
  };
}
