# TODO: find a way to build the benchmarks via crate2nix
{
  depot,
  pkgs,
  lib,
  ...
}:

(depot.snix.crates.workspaceMembers.snix-eval.build.override {
  runTests = true;
}).overrideAttrs
  (old: rec {
    meta.ci.targets = lib.filter (x: lib.hasPrefix "with-features" x || x == "no-features") (
      lib.attrNames passthru
    );
    passthru =
      old.passthru
      // (depot.snix.utils.mkFeaturePowerset {
        inherit (old) crateName;
        features = [ "nix_tests" ];
        override.testInputs = [ pkgs.nix ];
      });
  })
