let
  passToSnixStoreDaemonAll = ''
    grpc_pass unix:/run/snix-store-daemon.sock;
    grpc_buffer_size 1m;

    client_max_body_size 0;
  '';
  passToSnixStoreDaemonTrusted = ''
    # build03
    allow 116.202.234.220;
    allow 2a01:4f8:241:4de7::1;

    deny all;
    ${passToSnixStoreDaemonAll}
  '';

in
{
  imports = [
    ./base.nix
  ];

  services.nginx.virtualHosts."cache.snix.dev" = {
    forceSSL = true;
    enableACME = true;
    locations."/".proxyPass = "http://build03.infra.snix.dev:5000";

    locations."/grpc.reflection.v1alpha.ServerReflection".extraConfig = passToSnixStoreDaemonAll;
    locations."/grpc.reflection.v1.ServerReflection".extraConfig = passToSnixStoreDaemonAll;
    locations."/snix.castore.v1.BlobService/Stat".extraConfig = passToSnixStoreDaemonAll;
    locations."/snix.castore.v1.BlobService/Read".extraConfig = passToSnixStoreDaemonAll;
    locations."/snix.castore.v1.BlobService/Put".extraConfig = passToSnixStoreDaemonTrusted;
    locations."/snix.castore.v1.DirectoryService/Get".extraConfig = passToSnixStoreDaemonAll;
    locations."/snix.castore.v1.DirectoryService/Put".extraConfig = passToSnixStoreDaemonTrusted;

    locations."/snix.store.v1.PathInfoService/Get".extraConfig = passToSnixStoreDaemonAll;
    locations."/snix.store.v1.PathInfoService/Put".extraConfig = passToSnixStoreDaemonTrusted;
    locations."/snix.store.v1.PathInfoService/CalculateNAR".extraConfig = passToSnixStoreDaemonTrusted;
    locations."/snix.store.v1.PathInfoService/List".extraConfig = passToSnixStoreDaemonTrusted;
  };
}
