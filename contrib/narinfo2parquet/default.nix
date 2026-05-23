{ pkgs, depot, ... }:

(pkgs.callPackage ./Cargo.nix {
  defaultCrateOverrides = (depot.snix.utils.defaultCrateOverridesForPkgs pkgs) // {
    narinfo2parquet = prev: {
      src = depot.snix.utils.filterRustCrateSrc { root = prev.src.origSrc; };
    };
  };
}).rootCrate.build.overrideAttrs
  {
    meta.ci.targets = [ "crate2nix-check" ];
    passthru.crate2nix-check = depot.snix.utils.mkCrate2nixFastCheck ./Cargo.nix;
  }
