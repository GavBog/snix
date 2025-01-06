{ config, ... }:

{
  imports = [
    ./base.nix
  ];

  config = {
    # Listen on a special IPv4 & IPv6 specialized for mail. 
    # This NGINX has only one role: obtain TLS/SSL certificates for the mailserver. 
    # All the TLS, IMAP, SMTP stuff is handled directly by the mailserver runtime. 
    # This is why you will not see any `stream { }` block here.
    services.nginx.virtualHosts.stalwart = {
      serverName = "mail.snix.dev";
      enableACME = true;
      forceSSL = true;

      listenAddresses = [
        "127.0.0.2"
        "49.12.112.149"
        "[2a01:4f8:c013:3e62::2]"
      ];
    };
  };
}
