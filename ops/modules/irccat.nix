{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.irccat;
  description = "irccat - forward messages to IRC";

  # irccat expects to read its configuration from the *current
  # directory*, and its configuration contains secrets.
  #
  # To make this work we construct the JSON configuration file and
  # then recursively merge it with an on-disk secret using jq on
  # service launch.
  configJson = pkgs.writeText "irccat.json" (builtins.toJSON cfg.config);
in
{
  options.services.irccat = {
    enable = lib.mkEnableOption description;

    config = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything; # varying value types
      description = "Configuration structure (unchecked!)";
    };

    secretsFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to the secrets file to be merged";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.irccat = {
      inherit description;
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      wants = [ "network.target" ];

      serviceConfig = {
        ExecStartPre = (
          pkgs.writeShellScript "merge-irccat-config" ''
            if [ ! -f "$CREDENTIALS_DIRECTORY/secrets" ]; then
              echo "irccat secrets file is missing"
              exit 1
            fi

            # jq's * is the recursive merge operator
            ${pkgs.jq}/bin/jq -s '.[0] * .[1]' ${configJson} "$CREDENTIALS_DIRECTORY/secrets" \
              > /var/lib/irccat/irccat.json
          ''
        );

        ExecStart = "${pkgs.irccat}/bin/irccat";
        DynamicUser = true;
        StateDirectory = "irccat";
        WorkingDirectory = "/var/lib/irccat";
        LoadCredential = "secrets:${cfg.secretsFile}";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
