# Nix helpers for projects under //snix
{
  pkgs,
  lib,
  depot,
  here,
  ...
}:

let
  # Load the crate2nix crate tree.
  crates = pkgs.callPackage ./Cargo.nix {
    defaultCrateOverrides = here.utils.defaultCrateOverridesForPkgs pkgs;
  };

  commonCraneArgs = {
    src = "${src}";
    strictDeps = true;
    nativeBuildInputs = with pkgs; [
      pkg-config
      protobuf
    ];
    PROTO_ROOT = protos;
    SNIX_BUILD_SANDBOX_SHELL = "/homeless-shelter";
    doInstallCargoArtifacts = false;
  };
  cargoArtifacts = depot.third_party.crane.lib.buildDepsOnly (
    commonCraneArgs // { doInstallCargoArtifacts = true; }
  );
  nightlyCargoArtifacts = depot.third_party.crane.libNightly.buildDepsOnly (
    commonCraneArgs // { doInstallCargoArtifacts = true; }
  );

  # The cleaned sources.
  src = depot.third_party.gitignoreSource ./.;

  # Target containing *all* snix proto files.
  # Useful for workspace-wide cargo invocations (doc, clippy)
  protos = pkgs.symlinkJoin {
    name = "snix-all-protos";
    paths = [
      here.build.protos.protos
      here.castore.protos.protos
      here.store.protos.protos
    ];
  };
in
{
  inherit
    crates
    protos
    commonCraneArgs
    cargoArtifacts
    ;

  # Provide the snix logo in both .webp and .png format.
  logo =
    pkgs.runCommand "logo"
      {
        nativeBuildInputs = [ pkgs.imagemagick ];
      }
      ''
        mkdir -p $out
        cp ${./logo.webp} $out/logo.webp
        convert $out/logo.webp $out/logo.png
      '';

  # Provide a shell for the combined dependencies of all snix Rust
  # projects. Note that as this is manually maintained it may be
  # lacking something, but it is required for some people's workflows.
  #
  # This shell can be entered with e.g. `mg shell //snix:shell`.
  # This is a separate file, so it can be used individually in the snix josh
  # workspace too.
  shell = (import ./shell.nix { inherit pkgs; });

  # Shell, but with tools necessary to run the integration tests
  shell-integration = (
    import ./shell.nix {
      inherit pkgs;
      withIntegration = true;
    }
  );

  # Build the Rust documentation for publishing on snix.dev/rustdoc.
  rust-docs = depot.third_party.crane.cargoDocsRs (
    commonCraneArgs
    // {
      name = "snix-rust-docs";
      cargoArtifacts = nightlyCargoArtifacts;
      RUSTDOCFLAGS = "-D rustdoc::broken-intra-doc-links --document-private-items --enable-index-page";
      packages = [
        "snix-build"
        "snix-castore"
        "snix-castore-http"
        "snix-cli"
        "snix-cli-eval"
        "snix-eval"
        "snix-glue"
        "nar-bridge"
        "nix-compat"
        "nix-daemon"
        "snix-serde"
        "snix-store"
        "snix-tracing"
      ];
    }
  );

  # Run cargo clippy. We run it with --deny warnings, so warnings cause a nonzero
  # exit code.
  clippy = depot.third_party.crane.lib.cargoClippy (
    commonCraneArgs
    // {
      name = "snix-clippy";
      inherit cargoArtifacts;
      cargoClippyExtraArgs = "--all-targets --no-deps --all-features -- --deny warnings";
    }
  );

  doc-tests = depot.third_party.crane.lib.cargoDocTest (
    commonCraneArgs
    // {
      name = "snix-doc-tests";
      inherit cargoArtifacts;
    }
  );

  crate2nix-check = here.utils.mkCrate2nixFastCheck ./Cargo.nix;

  meta.ci.targets = [
    "clippy"
    "shell"
    "shell-integration"
    "rust-docs"
    "crate2nix-check"
  ];

  utils = import ./utils.nix { inherit pkgs lib depot; };
}
