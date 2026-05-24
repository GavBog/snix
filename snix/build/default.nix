{
  depot,
  lib,
  pkgs,
  ...
}:

depot.snix.crates.workspaceMembers.snix-build.build.override {
  runTests = true;
  testPreRun = ''
    export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
  '';
}
