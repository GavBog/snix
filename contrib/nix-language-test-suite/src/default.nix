{ depot, pkgs, ... }:

depot.nix.readTree.drvTargets {

  crate2nix-check = depot.snix.utils.mkCrate2nixFastCheck ./Cargo.nix;

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
