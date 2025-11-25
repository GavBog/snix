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
  # Not available in nixpkgs.
  # Raito: If you want this to disappear, please send the PR yourself.
  alertmanager-irc-relay = super.callPackage depot.third_party.alertmanager-irc-relay.package { };

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
      # TODO(Kranzes): Remove in next release.
      ./patches/crate2nix-0001-Fix-Use-mkDerivation-with-src-instead-of-runCommand.patch
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

  # macFUSE bump containing fix for https://github.com/osxfuse/osxfuse/issues/974
  # https://github.com/NixOS/nixpkgs/pull/320197
  fuse =
    if super.stdenv.isDarwin then
      super.fuse.overrideAttrs (old: rec {
        version = "4.8.0";
        src = super.fetchurl {
          url = "https://github.com/osxfuse/osxfuse/releases/download/macfuse-${version}/macfuse-${version}.dmg";
          hash = "sha256-ucTzO2qdN4QkowMVvC3+4pjEVjbwMsB0xFk+bvQxwtQ=";
        };
      })
    else
      super.fuse;

  # https://github.com/thuliteio/doks/pull/1356
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
}
