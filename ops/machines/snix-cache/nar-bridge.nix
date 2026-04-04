{
  config,
  depot,
  ...
}:
let
  mod = name: depot.path.origSrc + ("/ops/modules/" + name);
in

{
  imports = [
    (mod "nar-bridge.nix")
  ];

  services.nar-bridge = {
    enable = true;
    extraArgs = [
      "--tracer"
      "otlp"
    ];
    package = depot.snix.cli.nar-bridge.with-features-xp-store-composition-cli-otlp;

    settings = {
      blobservices = {
        root = {
          type = "objectstore";
          object_store_url = "file:///tank/nar-bridge/blobs.object_store";
          object_store_options = { };
        };
      };

      directoryservices = {
        root = {
          type = "redb";
          path = "/var/lib/nar-bridge/directories.redb";
        };
      };

      pathinfoservices = {
        root = {
          type = "cache";
          near = "&redb";
          far = "&cache-nixos-org";
        };

        redb = {
          type = "redb";
          path = "/var/lib/nar-bridge/pathinfo.redb";
        };

        "cache-nixos-org" = {
          type = "nix";
          base_url = "https://cache.nixos.org";
          blob_service = "&root";
          directory_service = "&root";
          trusted_public_keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          ];
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    # Put the blobs on the big disk
    "d /tank/nar-bridge 0755 nar-bridge nar-bridge -"
    "d /tank/nar-bridge/blobs.object_store 0755 nar-bridge nar-bridge -"
    # Cache responses on NVME
    "d /var/cache/nginx 0755 ${config.services.nginx.user} ${config.services.nginx.group} -"
  ];

  systemd.services.nar-bridge = {
    # Ensure /tank is mounted, which is where we the blobservice reads from.
    unitConfig.RequiresMountsFor = "/tank";

    # twice the normal allowed limit, same as nix-daemon
    serviceConfig.LimitNOFILE = "1048576";
  };
}
