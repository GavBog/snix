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
    (mod "snix-store-daemon.nix")
  ];

  services.snix-store-daemon = {
    enable = true;
    package = depot.snix.cli.store.with-features-xp-store-composition-cli-tonic-reflection-otlp-cloud;

    settings = {
      blobservices = {
        root = {
          type = "objectstore";
          object_store_url = "s3://snix-ci-cache/blobs";
          object_store_options = { };
        };
      };

      directoryservices = {
        root = {
          type = "redb";
          path = "/var/lib/snix-store/directories.redb";
        };
      };

      pathinfoservices = {
        root = {
          type = "redb";
          path = "/var/lib/snix-store/pathinfo.redb";
        };
      };
    };
  };
  systemd.services.snix-store-daemon = {
    serviceConfig.LoadCredential = "aws_config_file:${config.age.secrets.ci-cache-bucket-credentials.path}";
    environment.AWS_CONFIG_FILE = "%d/aws_config_file";
    environment.TRACER = "otlp";
  };
}
