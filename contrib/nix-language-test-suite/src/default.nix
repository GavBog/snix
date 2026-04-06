{ depot, pkgs, ... }:

depot.nix.readTree.drvTargets {
  crate2nix-check =
    let
      crate2nix-check = depot.snix.utils.mkCrate2nixCheck ./Cargo.nix;
    in
    crate2nix-check.command.overrideAttrs {
      meta.ci.extraSteps = {
        inherit crate2nix-check;
      };
    };

  crates = pkgs.callPackage ./Cargo.nix {
    defaultCrateOverrides = (depot.snix.utils.defaultCrateOverridesForPkgs pkgs) // {
      nix-language-test-suite-cppnix = prev: {
        TEST_SUITE_DIR = "${../tests}";
      };

      nix-language-test-suite-snix = prev: {
        TEST_SUITE_DIR = "${../tests}";
      };
    };
  };
}
