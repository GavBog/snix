{ config, ... }:
let
  host = "auth.snix.dev";
  realm = "snix-project";
in
{
  imports = [
    ./base.nix
  ];

  config = {
    services.nginx.virtualHosts."${host}" = {
      serverName = host;
      enableACME = true;
      forceSSL = true;

      locations."/" = {
        recommendedProxySettings = true;
        proxyPass = "http://127.0.0.1:9091";
        extraConfig = ''
          proxy_pass_header Authorization;

          proxy_busy_buffers_size   512k;
          proxy_buffers   4 512k;
          proxy_buffer_size   256k;

          # Allow clients with Auth hardcoded to use our base path.
          #
          # XXX: ok so this is horrible. For some reason gerrit explodes if
          # it receives a redirect when doing auth. But we need to redirect
          # the browser to reuse sessions. Thus, user agent scanning.
          if ($http_user_agent ~* "^Java.*$") {
            rewrite ^/auth/(.*)$ /$1 last;
          }
          rewrite ^/auth/(.*)$ /$1 redirect;

          # Hacks to make us compatible with authenticators that expect GitLab's format.
          rewrite ^/realms/${realm}/protocol/openid-connect/api/v4/user$ /realms/${realm}/protocol/openid-connect/userinfo;
          rewrite ^/realms/${realm}/protocol/openid-connect/oauth/authorize$ /realms/${realm}/protocol/openid-connect/auth?scope=openid%20email%20profile;
          rewrite ^/realms/${realm}/protocol/openid-connect/oauth/token$ /realms/${realm}/protocol/openid-connect/token;
        '';
      };

      # Forward our admin address to our default realm.
      locations."= /admin".extraConfig = "return 302 https://${host}/admin/snix-project/console/;";
      locations."= /superadmin".extraConfig = "return 302 https://${host}/admin/master/console/;";

      # Forward our root address to the account management portal.
      locations."= /".extraConfig = "return 302 https://${host}/realms/${realm}/account;";
    };
  };
}
