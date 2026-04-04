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
        // Accept OTLP on localhost and forward.
        otelcol.receiver.otlp "main" {
          grpc {
            endpoint = "[::1]:4317"
          }

          http {
            endpoint = "[::1]:4318"
          }

          output {
            logs = [otelcol.exporter.loki.default.input]
            metrics = [otelcol.exporter.prometheus.default.input]
            traces = [otelcol.exporter.otlphttp.tempo.input]
          }
        }

        // convert OTLP metrics to Prometheus format
        otelcol.exporter.prometheus "default" {
          forward_to = [prometheus.remote_write.default.receiver]
        }

        // Convert OTLP logs to Loki format
        otelcol.exporter.loki "default" {
          forward_to = [loki.write.default.receiver]
        }

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
          forward_to = [prometheus.remote_write.default.receiver]
        }

        // Configure a prometheus.scrape component to collect Alloy metrics.
        prometheus.exporter.self "default" {}
        prometheus.scrape "self" {
          targets    = prometheus.exporter.self.default.targets
          forward_to = [prometheus.remote_write.default.receiver]
        }

        prometheus.remote_write "default" {
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

        loki.relabel "journal" {
          forward_to = []
          rule {
            source_labels = ["__journal__systemd_unit"]
            target_label = "systemd_unit"
          }
          rule {
            source_labels = ["__journal__hostname"]
            target_label = "nodename"
          }
          rule {
            source_labels = ["__journal_syslog_identifier"]
            target_label = "syslog_identifier"
          }
        }

        loki.source.journal "journal" {
          forward_to = [loki.write.default.receiver]
          max_age = "12h"

          labels = {job = "systemd-journal"}
          relabel_rules = loki.relabel.journal.rules
        }

        loki.write "default" {
          endpoint {
            url = "https://loki.snix.dev/loki/api/v1/push"
            basic_auth {
              username = "promtail" // FUTUREWORK: rename this
              password_file = format("%s/metrics_remote_write_password", env("CREDENTIALS_DIRECTORY"))
            }
          }
          external_labels = {
            hostname = constants.hostname,
          }
        }

        // Push to tempo via otlp-http.
        otelcol.exporter.otlphttp "tempo" {
          client {
            endpoint = "https://tempo.snix.dev"
            auth = otelcol.auth.basic.creds.handler
          }
        }

        local.file "creds_password" {
          filename = format("%s/metrics_remote_write_password", sys.env("CREDENTIALS_DIRECTORY"))
          is_secret = true
        }

        otelcol.auth.basic "creds" {
          username = "promtail" // FUTUREWORK: rename this
          password = local.file.creds_password.content
          // FUTUREWORK: update to client_auth once alloy is bumped
          // client_auth {
          //   username = "promtail" // FUTUREWORK: rename this
          //   password_file = format("%s/metrics_remote_write_password", env("CREDENTIALS_DIRECTORY"))
          // }
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
            forward_to = [prometheus.remote_write.default.receiver]
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
