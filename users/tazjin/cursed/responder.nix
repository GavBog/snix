{ depot, ... }:

let
  inherit (depot.users.sterni.nix.html)
    __findFile
    esc
    ;

  # CGI envvars: https://www.instanet.com/cgi/env.html
  method = builtins.getEnv "REQUEST_METHOD";
  path = builtins.getEnv "PATH_INFO";

  rawQuery = builtins.getEnv "QUERY_STRING";
  query = with builtins; let
    pairs = (filter (s: isString s && s != "") (split "&" rawQuery));
    tuples = filter (l: length l > 0) (map (p: filter (s: isString s) (split "=" p)) pairs);
    mkAttr = t: {
      name = elemAt t 0;
      value = elemAt t 1;
    };
  in
  listToAttrs (map mkAttr tuples);

  default = let {
  hasQuery = if builtins.length (builtins.attrNames query) > 0 then "?" else "";
  body = <html> { lang = "en"; } [
    (<head> { } [
      (<title> { } "some cursed nix")
    ])
    (<body> { } [
      (<p> { } "hello volgasprint")
      (<p> { } [ method " " path hasQuery rawQuery ])
      (<p> { } (builtins.toJSON query))
    ])
  ];
  };

  greeter = withDoctype (<html> { lang = "en"; } [
    (<head> { } [
      (<title> { } "hello there")
    ])
    (<body> { } [
      (<p> { } "hello ${query.name or "unknown"}")
    ])
  ]);

  weather = let {
  town = query.town or "Kazan";
  w = builtins.fetchurl "https://wttr.in/${town}?";
  rendered = with depot.third_party.nixpkgs; runCommand "weather-${town}" { } ''
    cat ${w} | ${ansi2html}/bin/ansi2html > $out
  '';

  body = builtins.readFile "${rendered}";
  };

  routes = {
    "/other" = (withDoctype (<html> { lang = "en"; } [
      (<head> { } [
        (<title> { } "other endpoint")
      ])
      (<body> { } [
        (<p> { } "this is another route")
      ])
    ]));
    "/greeter" = greeter;
    "/weather" = weather;
  }."${path}" or default;

in
depot.web.bubblegum.respond "OK"
{
  "Content-Type" = "text/html";
}
  routes
