# Configure restic backups to S3-compatible storage, in our case
# Yandex Cloud Storage.
#
# When adding a new machine, the repository has to be initialised once. Refer to
# the Restic documentation for details on this process.
{ config, depot, lib, pkgs, ... }:

let
  cfg = config.services.depot.restic;
  description = "Restic backups to Yandex Cloud";
  mkStringOption = default: lib.mkOption {
    inherit default;
    type = lib.types.str;
  };
in
{
  options.services.depot.restic = {
    enable = lib.mkEnableOption description;
    bucketEndpoint = mkStringOption "storage.yandexcloud.net";
    bucketName = mkStringOption "tvl-backups";
    bucketCredentials = mkStringOption "/run/agenix/yc-restic";
    repository = mkStringOption config.networking.hostName;
    interval = mkStringOption "hourly";

    paths = with lib; mkOption {
      description = "Directories that should be backed up";
      type = types.listOf types.str;
    };

    exclude = with lib; mkOption {
      description = "Files that should be excluded from backups";
      type = types.listOf types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets = {
      restic-password.file = depot.ops.secrets."restic-${config.networking.hostName}.age";
      yc-restic.file = depot.ops.secrets."yc-restic.age";
    };

    systemd.services.restic = {
      description = "Backups to Yandex Cloud";

      script = "${pkgs.restic}/bin/restic backup ${lib.concatStringsSep " " cfg.paths}";

      environment = {
        RESTIC_REPOSITORY = "s3:${cfg.bucketEndpoint}/${cfg.bucketName}/${cfg.repository}";
        AWS_SHARED_CREDENTIALS_FILE = cfg.bucketCredentials;
        RESTIC_PASSWORD_FILE = "/run/agenix/restic-password";
        RESTIC_CACHE_DIR = "/var/backup/restic/cache";

        RESTIC_EXCLUDE_FILE =
          builtins.toFile "exclude-files" (lib.concatStringsSep "\n" cfg.exclude);
      };
    };

    systemd.timers.restic = {
      wantedBy = [ "multi-user.target" ];
      timerConfig.OnCalendar = cfg.interval;
    };

    environment.systemPackages = [ pkgs.restic ];
  };
}
