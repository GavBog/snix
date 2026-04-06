{
  depot,
  pkgs,
  ...
}:
depot.contrib.nix-language-test-suite.src.crates.workspaceMembers.nix-language-test-suite-snix.build.override
  {
    runTests = true;
    testCrateFlags = [ "--nocapture" ];
    testPreRun = ''
      export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
    '';
  }
