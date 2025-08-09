{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.alertmanager-irc-relay;
  yaml = pkgs.formats.yaml { };
  configFile = yaml.generate "config.yaml" cfg.settings;
  inherit (lib)
    mkEnableOption
    mkIf
    types
    mkOption
    mapAttrs
    mkPackageOption
    ;
in
{
  options.services.alertmanager-irc-relay = {
    enable = mkEnableOption "Alertmanager IRC relay";
    package = mkPackageOption pkgs "alertmanager-irc-relay" { };
    settings = mkOption {
      type = types.attrsOf yaml.type;
    };
    environmentFiles = mkOption {
      type = types.listOf types.path;
    };
  };

  config = mkIf cfg.enable {
    systemd.services.alertmanager-irc-relay = {
      description = "Alertmanager IRC Relay Service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} --config ${configFile}";
        Restart = "always";
        DynamicUser = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        EnvironmentFile = cfg.environmentFiles;
      };
    };

    services.alertmanager-irc-relay.settings = mapAttrs (_: lib.mkDefault) {
      http_host = "localhost";
      http_port = 8000;

      msg_once_per_alert_group = true;
      use_privmsg = false;

      msg_template = "Alert {{ .Labels.alertname }} on {{ .Labels.instance }} is {{ .Status }}";
      alert_buffer_size = 2048;
    };
  };
}
