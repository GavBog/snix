{ depot
, config
, lib
, ...
}:
let
  cfg = config.infra.monitoring.grafana-agent;
  inherit (lib) mkEnableOption mkOption mkIf types;
  passwordAsCredential = "\${CREDENTIALS_DIRECTORY}/password";
in
{
  options.infra.monitoring.grafana-agent = {
    enable = (mkEnableOption "Grafana Agent") // { default = true; };

    exporters = mkOption {
      description = ''
        Set of additional exporters to scrape.

        The attribute name will be used as `job_name`
        internally, which ends up exported as `job` label
        on all metrics of that exporter.
      '';
      type = types.attrsOf (types.submodule ({ config, name, ... }: {
        options.port = mkOption {
          description = "Exporter port";
          type = types.int;
        };
        options.scrapeConfig = mkOption {
          description = "Prometheus scrape config";
          type = types.attrs;
        };
        config.scrapeConfig = lib.mkMerge [{
          job_name = name;
          static_configs = [
            { targets = [ "localhost:${toString config.port}" ]; }
          ];
        }];
      }));
      default = { };
    };
  };

  config = mkIf cfg.enable {
    age.secrets.grafana-agent-password.file = depot.ops.secrets."grafana-agent-password.age";

    services.grafana-agent = {
      enable = true;
      credentials = lib.mkMerge ([{ password = config.age.secrets.grafana-agent-password.path; }] ++
        lib.mapAttrsToList (name: value: value.secrets) config.infra.monitoring.grafana-agent.exporters);
      settings = {
        metrics = {
          global.remote_write = [
            {
              url = "https://mimir.snix.dev/api/v1/push";
              basic_auth = {
                username = "promtail";
                password_file = passwordAsCredential;
              };
            }
          ];
          global.external_labels = {
            hostname = config.networking.hostName;
          };
          configs = [
            {
              name = config.networking.hostName;
              scrape_configs = lib.mapAttrsToList (name: value: value.scrapeConfig) config.infra.monitoring.grafana-agent.exporters;
            }
          ];
        };
        # logs = {
        #   global.clients = [
        #     {
        #       url = "https://loki.forkos.org/loki/api/v1/push";
        #       basic_auth = {
        #         username = "promtail";
        #         password_file = passwordAsCredential;
        #       };
        #     }
        #   ];
        #   configs = [
        #     {
        #       name = "journald";
        #       scrape_configs = [
        #         {
        #           job_name = "system";
        #           journal = {
        #             max_age = "12h";
        #             labels = {
        #               job = "systemd-journal";
        #               host = config.networking.hostName;
        #             };
        #           };
        #           relabel_configs = [
        #             {
        #               source_labels = [ "__journal__systemd_unit" ];
        #               target_label = "unit";
        #             }
        #           ];
        #         }
        #       ];
        #     }
        #   ];
        #   positions_directory = "\${STATE_DIRECTORY}/positions";
        # };
        integrations.node_exporter.enable_collectors = [
          "processes"
          "systemd"
        ];
      };
    };
  };
}
