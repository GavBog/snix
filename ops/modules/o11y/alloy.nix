{
  depot,
  config,
  lib,
  ...
}:
let
  cfg = config.infra.monitoring.alloy;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    mapAttrs'
    nameValuePair
    ;
in
{
  options.infra.monitoring.alloy = {
    enable = (mkEnableOption "Grafana Alloy") // {
      default = true;
    };

    exporters = mkOption {
      description = ''
        Set of additional exporters to scrape.

        The attribute name will be used as `job_name`
        internally, which ends up exported as `job` label
        on all metrics of that exporter.
      '';
      type = types.attrsOf (
        types.submodule (
          { config, name, ... }:
          {
            options.port = mkOption {
              description = "Exporter port";
              type = types.int;
            };
          }
        )
      );
      default = { };
    };
  };

  config = mkIf cfg.enable {
    age.secrets.alloy-password.file = depot.ops.secrets."grafana-agent-password.age";

    services.alloy.enable = true;

    environment.etc = {
      "alloy/config.alloy".text = ''
        prometheus.exporter.unix "default" {
          enable_collectors = [
            "processes",
            // cannot work currently, as alloy cannot talk to dbus:
            // "systemd"
          ]
        }

        // Configure node exporter
        prometheus.scrape "node_exporter" {
          targets = prometheus.exporter.unix.default.targets
          forward_to = [prometheus.remote_write.mimir.receiver]
        }

        // Configure a prometheus.scrape component to collect Alloy metrics.
        prometheus.exporter.self "default" {}
        prometheus.scrape "self" {
          targets    = prometheus.exporter.self.default.targets
          forward_to = [prometheus.remote_write.mimir.receiver]
        }

        prometheus.remote_write "mimir" {
          endpoint {
            url = "https://mimir.snix.dev/api/v1/push"
            basic_auth {
              username = "promtail" // FUTUREWORK: rename this
              password_file = format("%s/metrics_remote_write_password", env("CREDENTIALS_DIRECTORY"))
            }
          }
          external_labels = {
            hostname = constants.hostname,
          }
        }
      '';
    }
    // (mapAttrs' (
      name: v:
      nameValuePair "alloy/scrape_${name}.alloy" {
        text = ''
          prometheus.scrape "${name}" {
            targets = [
              {"__address__" = "localhost:${toString v.port}"},
            ]
            forward_to = [prometheus.remote_write.mimir.receiver]
          }
        '';
      }
    ) cfg.exporters);

    systemd.services.alloy.serviceConfig = {
      LoadCredential = [
        "metrics_remote_write_password:${config.age.secrets.alloy-password.path}"
      ];
    };
  };
}
