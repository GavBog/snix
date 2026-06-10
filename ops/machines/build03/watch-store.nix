{ pkgs, depot, ... }:

{
  systemd.services."watch-store@" = {
    path = [ pkgs.lix ];
    serviceConfig = {
      ExecStart = "${pkgs.watch-store}/bin/watch-store-go";
      Type = "notify";
      User = "watch-store";
      DynamicUser = true;
      ProtectHome = true;
      ProtectSystem = true;
      MemoryDenyWriteExecute = true;
      ProtectControlGroups = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictNamespaces = true;
      Restart = "on-failure";
      RestartSec = 5;
      RestrictRealtime = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];

      StandardOutput = "socket";
      StandardError = "journal";
    };
  };

  systemd.sockets.watch-store = {
    wantedBy = [ "sockets.target" ];
    socketConfig.ListenStream = "/run/watch-store.sock";
    socketConfig.Accept = "yes";
  };

  systemd.services.snix-copy = {
    environment.OTEL_SERVICE_NAME = "snix.store.copy";
    environment.TRACER = "otlp";
    environment.BLOB_SERVICE_ADDR = "grpc+https://cache.snix.dev";
    environment.DIRECTORY_SERVICE_ADDR = "grpc+https://cache.snix.dev";
    environment.PATH_INFO_SERVICE_ADDR = "grpc+https://cache.snix.dev";
    serviceConfig = {
      ExecStart = "${depot.snix.cli.store.with-features-otlp}/bin/snix-store copy --jsonl /run/watch-store.sock";
      Type = "simple";
      User = "snix-copy";
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
    wantedBy = [ "multi-user.target" ];
  };
}
