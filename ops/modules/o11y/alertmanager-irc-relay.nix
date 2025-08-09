{ config, depot, ... }:
{
  imports = [
    depot.third_party.alertmanager-irc-relay.module
  ];

  services.alertmanager-irc-relay = {
    enable = true;
    settings = {
      irc_host = "irc.hackint.org";
      irc_port = 6697;
      irc_nickname = "silentfox";
      irc_channels = [
        {
          name = "#snix";
          password = "$CHANNEL_PASSWORD";
        }
      ];
    };
    environmentFiles = [
      config.age.secrets.alertmanager-irc-relay-environment.path
    ];
  };
}
