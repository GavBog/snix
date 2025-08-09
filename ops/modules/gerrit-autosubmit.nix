# Configuration for the Gerrit autosubmit bot (//ops/gerrit-autosubmit)
{
  depot,
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.services.depot.gerrit-autosubmit;
  description = "gerrit-autosubmit - autosubmit bot for Gerrit";
  mkStringOption =
    default:
    lib.mkOption {
      inherit default;
      type = lib.types.str;
    };
in
{
  options.services.depot.gerrit-autosubmit = {
    enable = lib.mkEnableOption description;
    gerritUrl = mkStringOption "https://cl.snix.dev";

    secretsFile =
      with lib;
      mkOption {
        description = "Path to a systemd EnvironmentFile containing secrets";
        default = config.age.secretsDir + "/gerrit-autosubmit";
        type = types.str;
      };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.gerrit-autosubmit = {
      inherit description;
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        ExecStart = "${depot.ops.gerrit-autosubmit}/bin/gerrit-autosubmit";
        DynamicUser = true;
        Restart = "always";
        EnvironmentFile = cfg.secretsFile;
      };

      environment = {
        GERRIT_URL = cfg.gerritUrl;
        GERRIT_USERNAME = "clbot";
      };
    };
  };
}
