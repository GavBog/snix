# Stalwart is an all-in-one mailserver in Rust.
# https://stalw.art/
{ config, lib, ... }:
let
  inherit (lib) mkOption mkEnableOption mkIf types;
  cfg = config.services.depot.stalwart;
  certs = config.security.acme.certs.${cfg.mailDomain} or (throw "NixOS-level ACME was not enabled for `${cfg.mailDomain}`: mailserver cannot autoconfigure!");
  mkBind = port: ip: "${ip}:${toString port}";
in
{
  options.services.depot.stalwart = {
    enable = mkEnableOption "Stalwart Mail server";

    listenAddresses = mkOption {
      type = types.listOf types.str;
      default = [
        "49.12.112.149"
        "[2a01:4f8:c013:3e62::2]"
      ];
    };

    mailDomain = mkOption {
      type = types.str;
      description = "The email domain, i.e. the part after @";
      example = "snix.dev";
    };
  };

  config = mkIf cfg.enable {
    # Open only from the listen addresses.
    networking.firewall.allowedTCPPorts = [ 25 587 143 443 ];
    services.stalwart-mail = {
      enable = true;
      settings = {
        certificate.letsencrypt = {
          cert = "file://${certs.directory}/fullchain.pem";
          private-key = "file://${certs.directory}/key.pem";
        };
        server = {
          hostname = cfg.mailDomain;
          tls = {
            certificate = "letsencrypt";
            enable = true;
            implicit = false;
          };
          listener = {
            smtp = {
              bind = map (mkBind 587) cfg.listenAddresses;
              protocol = "smtp";
            };
            imap = {
              bind = map (mkBind 143) cfg.listenAddresses;
              protocol = "imap";
            };
            mgmt = {
              bind = map (mkBind 443) cfg.listenAddresses;
              protocol = "https";
            };
          };
        };
        session = {
          rcpt = {
            directory = "in-memory";
            # Allow this server to be used as a relay for authenticated principals.
            relay = [
              { "if" = "!is_empty(authenticated_as)"; "then" = true; }
              { "else" = false; }
            ];
          };
          auth = {
            mechanisms = [ "PLAIN" ];
            directory = "in-memory";
          };
        };
        jmap.directory = "in-memory";
        queue.outbound.next-hop = [ "local" ];
        directory.in-memory = {
          type = "memory";
        };
      };
    };
  };
}
