{ depot, pkgs, ... }:
let
  lib = import depot.third_party.sources.crane { inherit pkgs; };
  libNightly = lib.overrideToolchain (
    p: p.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default)
  );
in
{
  inherit lib libNightly;

  cargoDocsRs =
    {
      packages ? [ ],
      cargoDocsRsExtraArgs ? "",
      cargoExtraArgs ? "--locked",
      ...
    }@origArgs:
    let
      args = builtins.removeAttrs origArgs [
        "packages"
        "cargoDocsRsExtraArgs"
        "cargoExtraArgs"
      ];
    in
    libNightly.mkCargoDerivation (
      args
      // {
        pnameSuffix = "-docs-rs";

        doInstallCargoArtifacts = args.doInstallCargoArtifacts or false;

        docInstallRoot = args.docInstallRoot or "";
        CARGO_BUILD_TARGET = pkgs.stdenv.hostPlatform.config;

        buildPhaseCargoCommand =
          if packages == [ ] then
            "cargo docs-rs ${cargoExtraArgs} --target $CARGO_BUILD_TARGET ${cargoDocsRsExtraArgs}"
          else
            ''
              ${pkgs.lib.concatMapStringsSep "\n" (
                p: "cargo docs-rs ${cargoExtraArgs} -p ${p} --target $CARGO_BUILD_TARGET ${cargoDocsRsExtraArgs}"
              ) packages}
            '';

        installPhaseCommand =
          args.installPhaseCommand or ''
            echo initial ''${CARGO_BUILD_TARGET:-} $docInstallRoot
            if [ -z "''${docInstallRoot:-}" ]; then
              docInstallRoot="''${CARGO_TARGET_DIR:-target}/''${CARGO_BUILD_TARGET:-}/doc"
              echo set $docInstallRoot

              if ! [ -d "''${docInstallRoot}" ]; then
                docInstallRoot="''${CARGO_TARGET_DIR:-target}/doc"
                echo default $docInstallRoot
              fi
            fi

            echo actual $docInstallRoot
            mkdir -p $out/share
            mv "''${docInstallRoot}" $out/share
          '';

        nativeBuildInputs = (args.nativeBuildInputs or [ ]) ++ [ depot.third_party.cargo-docs-rs ];
      }
    );
}
