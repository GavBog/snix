{
  config,
  lib,
  utils,
  pkgs,
  depot,
  ...
}:
let
  cfg = config.services.nar-bridge;

  package = depot.snix.cli.store-composition-cli;

  storeCompositionFormat = pkgs.formats.toml { };

  storeCompositionFile = storeCompositionFormat.generate "store-composition.toml" cfg.settings;

  args = [
    "--listen-address"
    "sd-listen"
    "--experimental-store-composition"
    storeCompositionFile
  ]
  ++ lib.optionals cfg.enableOTLP [ "--otlp" ];
in
{
  options = {
    services.nar-bridge = {
      enable = lib.mkEnableOption "nar-bridge service";

      enableOTLP = lib.mkEnableOption "support for OpenTelemetry";

      settings = lib.mkOption {
        type = storeCompositionFormat.type;
        default = { };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.nar-bridge = {
      isSystemUser = true;
      group = "nar-bridge";
    };

    users.groups.nar-bridge = { };

    systemd.sockets.nar-bridge = {
      description = "nar-bridge socket";
      wantedBy = [ "sockets.target" ];

      socketConfig = {
        LimitNOFILE = 65535;
        ListenStream = "/run/nar-bridge.sock";
        SocketMode = "0666";
        SocketUser = "root";
      };
    };

    systemd.services.nar-bridge = {
      description = "NAR Bridge";
      requires = [ "nar-bridge.socket" ];
      after = [ "nar-bridge.socket" ];
      wantedBy = [ "multi-user.target" ];
      environment.OTEL_SERVICE_NAME = "snix.nar-bridge";
      serviceConfig = {
        ExecStart = "${package}/bin/snix nar-bridge ${utils.escapeSystemdExecArgs args}";

        Restart = "always";
        RestartSec = "10";

        User = "nar-bridge";
        Group = "nar-bridge";
        StateDirectory = "nar-bridge";
      };
    };
  };
}
