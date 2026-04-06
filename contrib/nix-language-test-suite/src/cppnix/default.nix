{
  depot,
  pkgs,
  lib,
  ...
}:
let
  mkCppNixTests =
    nix:
    depot.contrib.nix-language-test-suite.src.crates.workspaceMembers.nix-language-test-suite-cppnix.build.override
      {
        runTests = true;
        testCrateFlags = [ "--nocapture" ];
        testInputs = [ nix ];
        testPreRun = ''
          export HOME=$(mktemp -d)

          # Needed for the rust runner
          export NIX_SANDBOX=true
          export NIX_VERSION=${lib.getName nix}-${lib.getVersion nix}
        '';
      };
in
depot.nix.readTree.drvTargets {
  nix_latest_verified = mkCppNixTests pkgs.nix;
  nix_2_3 = mkCppNixTests pkgs.nix_2_3;
  lix_latest = mkCppNixTests pkgs.lix;
}
