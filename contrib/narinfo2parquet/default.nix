{ pkgs, depot, ... }:

(pkgs.callPackage ./Cargo.nix {
  defaultCrateOverrides = (depot.snix.utils.defaultCrateOverridesForPkgs pkgs) // {
    narinfo2parquet = prev: {
      src = depot.snix.utils.filterRustCrateSrc { root = prev.src.origSrc; };
    };
  };
}).rootCrate.build.overrideAttrs
  {
    meta.ci.extraSteps.crate2nix = depot.snix.utils.mkCrate2nixCheck ./Cargo.nix;
  }
