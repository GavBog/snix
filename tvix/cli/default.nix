{ depot, pkgs, lib, ... }:

(depot.tvix.crates.workspaceMembers.tvix-cli.build.override {
  runTests = true;
  testPreRun = ''
    export SSL_CERT_FILE=/dev/null
  '';
}).overrideAttrs (finalAttrs: previousAttrs:

let
  tvix-cli = finalAttrs.finalPackage;

  benchmark-gnutime-format-string =
    description:
    "Benchmark: " +
    (builtins.toJSON {
      "${description}" = {
        kbytes = "%M";
        system = "%S";
        user = "%U";
      };
    });

  # You can run the benchmark with a simple `nix run`, like:
  #
  #  nix-build -A tvix.cli.meta.ci.extraSteps.benchmark-nixpkgs-cross-hello-outpath
  #
  # TODO(amjoseph): store these results someplace more durable, like git trailers
  #
  mkExprBenchmark = { expr, description }:
    let name = "tvix-cli-benchmark-${description}"; in
    (pkgs.runCommand name { } ''
      export SSL_CERT_FILE=/dev/null
      ${lib.escapeShellArgs [
        "${pkgs.time}/bin/time"
        "--format" "${benchmark-gnutime-format-string description}"
        "${tvix-cli}/bin/tvix"
        "--no-warnings"
        "-E" expr
      ]}
      touch $out
    '');

  mkNixpkgsBenchmark = attrpath:
    mkExprBenchmark {
      description = builtins.replaceStrings [ ".drv" ] [ "-drv" ] attrpath;
      expr = "(import ${pkgs.path} {}).${attrpath}";
    };

  # Constructs a Derivation invoking tvix-cli inside a build, ensures the
  # calculated tvix output path matches what's passed in externally.
  mkNixpkgsEvalTest =
    { attrPath ? null # An attribute that must already be accessible from `pkgs`. Should evaluate to a store path.
    , expr ? null # A Nix expression that should evaluate to a store path.
    , expectedPath # The expected store path that should match one of the above.
    }:
      assert lib.assertMsg (attrPath != null || expr != null) "Either 'attrPath' or 'expr' must be set.";
      let
        name = "tvix-eval-test-${builtins.replaceStrings [".drv"] ["-drv"] (if expr != null then "custom-expr" else attrPath)}";
      in
      (pkgs.runCommand name { } ''
        export SSL_CERT_FILE=/dev/null
        TVIX_OUTPUT=$(${tvix-cli}/bin/tvix --no-warnings -E '${if expr != null then expr else "(import ${pkgs.path} {}).${attrPath}"}')
        EXPECTED='${/* the verbatim expected Tvix output: */ "=> \"${builtins.unsafeDiscardStringContext expectedPath}\" :: string"}'

        echo "Tvix output: ''${TVIX_OUTPUT}"
        if [ "$TVIX_OUTPUT" != "$EXPECTED" ]; then
          echo "Correct would have been ''${EXPECTED}"
          exit 1
        fi

        echo "Output was correct."
        touch $out
      '');


  benchmarks = {
    benchmark-hello = (mkNixpkgsBenchmark "hello.outPath");
    benchmark-cross-hello = (mkNixpkgsBenchmark "pkgsCross.aarch64-multiplatform.hello.outPath");
    benchmark-firefox = (mkNixpkgsBenchmark "firefox.outPath");
    benchmark-cross-firefox = (mkNixpkgsBenchmark "pkgsCross.aarch64-multiplatform.firefox.outPath");
    # Example used for benchmarking LightSpan::Delayed in commit bf286a54bc2ac5eeb78c3d5c5ae66e9af24d74d4
    benchmark-nixpkgs-attrnames = (mkExprBenchmark { expr = "builtins.length (builtins.attrNames (import ${pkgs.path} {}))"; description = "nixpkgs-attrnames"; });
  };

  evalTests = {
    eval-nixpkgs-stdenv-drvpath = (mkNixpkgsEvalTest { attrPath = "stdenv.drvPath"; expectedPath = pkgs.stdenv.drvPath; });
    eval-nixpkgs-stdenv-outpath = (mkNixpkgsEvalTest { attrPath = "stdenv.outPath"; expectedPath = pkgs.stdenv.outPath; });
    eval-nixpkgs-hello-outpath = (mkNixpkgsEvalTest { attrPath = "hello.outPath"; expectedPath = pkgs.hello.outPath; });
    eval-nixpkgs-firefox-outpath = (mkNixpkgsEvalTest { attrPath = "firefox.outPath"; expectedPath = pkgs.firefox.outPath; });
    eval-nixpkgs-firefox-drvpath = (mkNixpkgsEvalTest { attrPath = "firefox.drvPath"; expectedPath = pkgs.firefox.drvPath; });
    eval-nixpkgs-cross-stdenv-outpath = (mkNixpkgsEvalTest { attrPath = "pkgsCross.aarch64-multiplatform.stdenv.outPath"; expectedPath = pkgs.pkgsCross.aarch64-multiplatform.stdenv.outPath; });
    eval-nixpkgs-cross-hello-outpath = (mkNixpkgsEvalTest { attrPath = "pkgsCross.aarch64-multiplatform.hello.outPath"; expectedPath = pkgs.pkgsCross.aarch64-multiplatform.hello.outPath; });
    # Our CI runner currently uses Nix version lower than 2.12, which means it uses the old JSON library.
    # The NixOS docs generate a JSON file with all the NixOS options, and so output is different between Tvix (and Nix 2.12+) and our CI runner's Nix version,
    # so we disable the NixOS docs generation for now. TODO(kranzes): Re-enable NixOS docs once the CI runner is using a newer Nix version.
    eval-nixpkgs-nixos-gnome-installer-drvpath = (mkNixpkgsEvalTest {
      expr = "(import ${pkgs.path}/nixos/release.nix { configuration = { documentation.nixos.enable = (import ${pkgs.path}/lib).mkForce false; }; }).iso_gnome.${pkgs.system}.drvPath";
      expectedPath = (import "${pkgs.path}/nixos/release.nix" { configuration.documentation.nixos.enable = lib.mkForce false; }).iso_gnome.${pkgs.system}.drvPath;
    });
    eval-nixpkgs-nixos-gnome-installer-outpath = (mkNixpkgsEvalTest {
      expr = "(import ${pkgs.path}/nixos/release.nix { configuration = { documentation.nixos.enable = (import ${pkgs.path}/lib).mkForce false; }; }).iso_gnome.${pkgs.system}.outPath";
      expectedPath = (import "${pkgs.path}/nixos/release.nix" { configuration.documentation.nixos.enable = lib.mkForce false; }).iso_gnome.${pkgs.system}.outPath;
    });
  };
in
{
  meta = {
    ci.targets = (builtins.attrNames benchmarks) ++ (builtins.attrNames evalTests);
  };

  # Expose benchmarks and evalTests as standard CI targets.
  passthru = previousAttrs.passthru // benchmarks // evalTests;
})
