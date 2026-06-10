{
  depot,
  config,
  ...
}:

let
  tls_client_cert_path = depot.ops.pki.host_certificates."build03.infra.snix.dev";
  tls_client_key_path = "/run/credentials/snix-copy.service/mtls-private-key.pem";
  storeUrl = "grpc+https://cache.snix.dev?tls-client-cert-path=${tls_client_cert_path}&tls-client-key-path=${tls_client_key_path}";
in
{
  systemd.services.snix-copy = {
    environment.OTEL_SERVICE_NAME = "snix.store.copy";
    environment.TRACER = "otlp";
    environment.BLOB_SERVICE_ADDR = storeUrl;
    environment.DIRECTORY_SERVICE_ADDR = storeUrl;
    environment.PATH_INFO_SERVICE_ADDR = storeUrl;
    serviceConfig = {
      ExecStart = "${depot.snix.cli.store.with-features-otlp}/bin/snix-store copy --jsonl /run/watch-store.sock";
      Type = "simple";
      User = "snix-copy";
      DynamicUser = true;
      ProtectHome = true;
      ProtectSystem = true;
      MemoryDenyWriteExecute = true;
      ProtectControlGroups = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      Restart = "on-failure";
      RestartSec = 5;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
      LoadCredential = [
        "mtls-private-key.pem:${config.age.secrets.mtls-private-key.path}"
      ];
    };
    wantedBy = [ "multi-user.target" ];
  };
}
