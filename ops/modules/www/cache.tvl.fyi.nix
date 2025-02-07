# Publicly serve builderball cache. This is an experimental setup, and separate
# from the "normal" harmonia cache on cache.tvl.su.
{ config, ... }:

let
  # This attrset forms a linked list of hosts, which delegate ACME fallbacks to
  # each other. These *must* form a circle, otherwise we may end up walking only
  # part of the ring.
  #
  # TODO: remove whitby from here, it is gone; leaving this code for now for
  # easier discovery when reconfiguring this.
  acmeFallback = host: ({
    whitby = "nevsky.cache.tvl.fyi";
    nevsky = "whitby.cache.tvl.fyi"; # GOTO 1
  })."${host}";
in
{
  imports = [
    ./base.nix
  ];

  config = {
    services.nginx.virtualHosts."cache.tvl.fyi" = {
      serverName = "cache.tvl.fyi";
      enableACME = true;
      forceSSL = true;

      # This enables fetching TLS certificates for the same domain on different
      # hosts. This config is kind of messy; it would be nice to generate a
      # correct ring from the depot fixpoint, but this may be impossible due to
      # infinite recursion. Please read the comment on `acmeFallback` above.
      #
      # TODO: whitby is gone, this is not needed at the moment
      # acmeFallbackHost = acmeFallback config.networking.hostName;

      extraConfig = ''
        location = /cache-key.pub {
            alias /run/agenix/nix-cache-pub;
        }

        location = / {
            proxy_pass http://${config.services.depot.harmonia.settings.bind};
        }

        location / {
            proxy_pass http://localhost:${toString config.services.depot.builderball.port};
        }
      '';
    };

    # participating hosts should use their local cache, otherwise they might end
    # up querying themselves from afar for data they don't have.
    networking.extraHosts = "127.0.0.1 cache.tvl.fyi";
  };
}
