{
  pkgs,
  depot,
  lib,
  ...
}:

(pkgs.callPackage ./Cargo.nix {
  defaultCrateOverrides = (depot.snix.utils.defaultCrateOverridesForPkgs pkgs) // {
    crunch-v2 = prev: {
      src = depot.snix.utils.filterRustCrateSrc rec {
        root = prev.src.origSrc;
        extraFileset = lib.fileset.fileFilter (f: f.hasExt "proto") root;
      };
      nativeBuildInputs = [ pkgs.protobuf ];
    };
  };
}).rootCrate.build.overrideAttrs
  {
    meta.ci.extraSteps.crate2nix-check = depot.snix.utils.mkCrate2nixCheck ./Cargo.nix;
  }
