{ pkgs, depot, ... }:

let
  inherit (builtins) readFile;
  inherit (depot.users) wpcarro;

  domain = "billandhiscomputer.com";

  globalVars = {
    inherit domain;
    homepage = "https://${domain}/";
    blog = "https://${domain}/blog";
    habits = "https://${domain}/habits";
    github = "https://github.com/wpcarro";
    linkedin = "https://linkedin.com/in/williampatrickcarroll";
    depotWork = "https://code.tvl.fyi/tree/users/wpcarro";
  };

  renderTemplate = src: vars: pkgs.substituteAll (globalVars // vars // {
    inherit src;
  });

  withBrand = contentHtml: renderTemplate ./fragments/template.html {
    inherit contentHtml;
  };

  # Create a simple static file server using nginx to serve `content`.
  nginxCfgFor = content: pkgs.writeText "nginx.conf" ''
    user nobody nobody;
    daemon off;
    error_log /dev/stdout info;
    pid /dev/null;
    events {}
    http {
      server {
        listen 8080;
        location / {
          root ${content};
        }
      }
    }
  '';
in
rec {
  inherit domain renderTemplate withBrand;

  content = pkgs.runCommand "wpcarro.dev" { } ''
    mkdir -p $out

    # /
    cp ${withBrand (readFile (renderTemplate ./fragments/homepage.html {}))} $out/index.html

    # /habits
    mkdir -p $out/habits
    cp -r ${wpcarro.website.habit-screens} $out/habits/index.html

    # /blog
    cp -r ${wpcarro.website.blog} $out/blog
  '';

  # Create a docker image suitable for Google Cloud Run (to save costs).
  image = pkgs.dockerTools.buildLayeredImage {
    name = "website";
    tag = "latest";
    contents = [ pkgs.fakeNss ];
    extraCommands = ''
      mkdir -p tmp/nginx_client_body
      mkdir -p var/log/nginx
    '';
    config = {
      Cmd = [ "${pkgs.nginx}/bin/nginx" "-c" (nginxCfgFor content) ];
      ExposedPorts = { "8080/tcp" = { }; };
    };
  };

  meta.ci.targets = [ "root" "image" ];
}
