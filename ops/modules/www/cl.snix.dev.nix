{ config, depot, ... }:

{
  imports = [
    ./base.nix
  ];

  config = {
    services.nginx.virtualHosts."cl-shortlink" = {
      serverName = "cl";
      extraConfig = "return 302 https://cl.snix.dev$request_uri;";
    };

    services.nginx.virtualHosts.gerrit = {
      serverName = "cl.snix.dev";
      enableACME = true;
      forceSSL = true;

      extraConfig = ''
        location / {
          proxy_pass http://localhost:4778;
          proxy_set_header  X-Forwarded-For $remote_addr;
          # The :443 suffix is a workaround for https://b.snix.dev/issues/88.
          proxy_set_header  Host $host:443;
        }

        # Retro-compatibility to TVL shortlinks.
        location ~ "^/q/([1-2]?[0-9]{1,4}|30000)$" {
          return 302 https://cl.tvl.fyi$request_uri;
        }

        location = /robots.txt {
          return 200 'User-agent: *\nAllow: /';
        }

        location /buildkite-status/ {
          proxy_pass http://buildkite-api-proxy/;
        }
      '';
    };

    services.nginx.upstreams.buildkite-api-proxy = {
      servers."unix:/run/buildkite-api-proxy.sock" = { };
    };

    systemd.services.buildkite-api-proxy = {
      serviceConfig = {
        LoadCredential = "buildkite-api-token:${config.age.secrets.buildkite-api-proxy-token.path}";
        ExecStart = "${depot.ops.buildkite-api-proxy}/bin/buildkite-api-proxy";
        Restart = "always";
        RestartSec = 5;
        User = "buildkite-api-proxy";
        DynamicUser = true;
        ProtectHome = true;
        ProtectSystem = true;
        MemoryDenyWriteExecute = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
      };
    };
    systemd.sockets.buildkite-api-proxy = {
      wantedBy = [ "sockets.target" ];
      socketConfig.ListenStream = "/run/buildkite-api-proxy.sock";
    };
  };
}
