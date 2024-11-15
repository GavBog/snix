{ depot, config, lib, pkgs, ... }:

let
  cfg = config.services.depot.irccat;
  description = "irccat - forward messages to IRC";

  # irccat expects to read its configuration from the *current
  # directory*, and its configuration contains secrets.
  #
  # To make this work we construct the JSON configuration file and
  # then recursively merge it with an on-disk secret using jq on
  # service launch.
  configJson = pkgs.writeText "irccat.json" (builtins.toJSON cfg.config);

  # Right now, merging configuration file with secrets and running the main
  # application needs to happen both in ExecStart=, due to
  # https://github.com/systemd/systemd/issues/19604#issuecomment-989279884
  mergeAndLaunch = pkgs.writeShellScript "merge-irccat-config" ''
    if [ ! -f "$CREDENTIALS_DIRECTORY/secrets" ]; then
      echo "irccat secrets file is missing"
      exit 1
    fi

    # jq's * is the recursive merge operator
    ${pkgs.jq}/bin/jq -s '.[0] * .[1]' ${configJson} "$CREDENTIALS_DIRECTORY/secrets" \
      > /var/lib/irccat/irccat.json

    exec ${depot.third_party.irccat}/bin/irccat
  '';
in
{
  options.services.depot.irccat = {
    enable = lib.mkEnableOption description;

    config = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything; # varying value types
      description = "Configuration structure (unchecked!)";
    };

    secretsFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to the secrets file to be merged";
      default = config.age.secretsDir + "/irccat";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.irccat = {
      inherit description;
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        ExecStart = "${mergeAndLaunch}";
        DynamicUser = true;
        StateDirectory = "irccat";
        WorkingDirectory = "/var/lib/irccat";
        LoadCredential = "secrets:${cfg.secretsFile}";
        Restart = "always";
      };
    };
  };
}
