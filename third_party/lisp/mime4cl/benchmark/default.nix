{ depot, pkgs, lib, ... }:

let
  # Example email that's going to push the parser due to its big attachment
  # of almost 200MB. We are using a GHC bindist since it's quite big and a
  # fixed output derivation that's already part of nixpkgs, so whitby only
  # needs to download it once (and it won't change).
  message = pkgs.runCommand "huge.mime"
    {
      nativeBuildInputs = [ pkgs.buildPackages.mblaze ];
    }
    ''
      mmime > $out <<EOF
      Subject: Test message with a big attachment

      Henlo world!

      #application/gzip#base64 ${pkgs.haskell.compiler.ghc963Binary.src}
      EOF
    '';

  inherit (depot.nix) buildLisp getBins;

  benchmark-program = buildLisp.program {
    name = "mime4cl-benchmark-program";

    deps = [
      {
        sbcl = buildLisp.bundled "uiop";
        default = buildLisp.bundled "asdf";
      }
      depot.third_party.lisp.mime4cl
    ];

    srcs = [
      ./bench.lisp
    ];

    main = "mime4cl-bench:main";
  };

  commands = bench: {
    mime4cl-message-parsing = "${bench} parse ${message}";
    mime4cl-attachment-extraction = "${bench} extract ${message}";
  };

  # TODO(sterni): expose this information from //nix/buildLisp and generate automatically
  lispImplementations = [ "sbcl" /* "ccl" "ecl" */ ];
in

(pkgs.writeShellScriptBin "mime4cl-benchmark" ''
  exec ${pkgs.hyperfine}/bin/hyperfine \
    ${
      lib.escapeShellArgs (
        lib.concatMap (impl:
          lib.concatLists (
            lib.mapAttrsToList (name: cmd:
              [ "-n" "${impl}-${name}" cmd ]
            ) (commands (let b = benchmark-program.${impl}; in "${b}/bin/${b.name}"))
          )
        ) lispImplementations
      )
    } \
    "$@"
'').overrideAttrs (oldAttrs: {
  passthru = oldAttrs.passthru or  { } // {
    inherit benchmark-program;
  };
})
