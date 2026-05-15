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

  # Use an old version of hugo, else the website only shows
  # "This line is from layouts/index.html."
  hugo = super.hugo.overrideAttrs (old: {
    version = "0.145.0";

    src = super.fetchFromGitHub {
      owner = "gohugoio";
      repo = "hugo";
      tag = "v0.145.0";
      hash = "sha256-5SV6VzNWGnFQBD0fBugS5kKXECvV1ZE7sk7SwJCMbqY=";
    };

    vendorHash = "sha256-aynhBko6ecYyyMG9XO5315kLerWDFZ6V8LQ/WIkvC70=";
  });

  watch-store = super.callPackage ./pkgs/watch-store.nix { };
}
