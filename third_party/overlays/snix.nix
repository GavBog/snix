# This overlay is used to make TVL-specific modifications in the
# nixpkgs tree, where required.
{
  lib,
  depot,
  localSystem,
  ...
}:

self: super:
depot.nix.readTree.drvTargets {
  # Avoid builds of mkShell derivations in CI.
  mkShell = super.lib.makeOverridable (
    args:
    (super.mkShell args).overrideAttrs (_: {
      passthru = {
        meta.ci.skip = true;
      };
    })
  );

  crate2nix = super.crate2nix.overrideAttrs (old: {
    patches = old.patches or [ ] ++ [
      # https://github.com/nix-community/crate2nix/pull/301
      ./patches/crate2nix-tests-debug.patch
    ];
  });

  evans = super.evans.overrideAttrs (old: {
    patches = old.patches or [ ] ++ [
      # add support for unix domain sockets
      # https://github.com/ktr0731/evans/pull/680
      ./patches/evans-add-support-for-unix-domain-sockets.patch
    ];
  });

}
