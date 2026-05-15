{ pkgs, ... }:

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
}
