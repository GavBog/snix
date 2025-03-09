{ depot, pkgs, ... }:

let
  inherit (pkgs) sbcl runCommand writeText;
  inherit (depot.nix.buildLisp) bundled;

  src = pkgs.srcOnly pkgs.sbcl.pkgs.cl-unicode;

  cl-unicode-base = depot.nix.buildLisp.library {
    name = "cl-unicode-base";
    deps = with depot.third_party.lisp; [
      cl-ppcre
    ];

    srcs = map (f: src + ("/" + f)) [
      "packages.lisp"
      "specials.lisp"
      "util.lisp"
    ];
  };

  cl-unicode-build = depot.nix.buildLisp.program {
    name = "cl-unicode-build";
    deps = with depot.third_party.lisp; [
      cl-unicode-base
      flexi-streams
      {
        ecl = bundled "asdf";
        default = bundled "uiop";
      }
    ];

    srcs = (map (f: src + ("/build/" + f)) [
      "util.lisp"
      "char-info.lisp"
      "read.lisp"
    ]) ++ [
      (runCommand "dump.lisp" { } ''
        substitute ${src}/build/dump.lisp $out \
          --replace ':defaults *this-file*' ":defaults (uiop:getcwd)"
      '')

      (writeText "export-create-source-files.lisp" ''
        (in-package :cl-unicode)
        (export 'create-source-files)
      '')
    ];

    main = "cl-unicode:create-source-files";
  };


  generated = runCommand "cl-unicode-generated" { } ''
    mkdir -p $out/build
    mkdir -p $out/test
    cd $out/build
    pwd
    ${cl-unicode-build}/bin/cl-unicode-build
  '';

in
depot.nix.buildLisp.library {
  name = "cl-unicode";
  deps = [ cl-unicode-base ];
  srcs = [
    "${src}/conditions.lisp"
    "${generated}/lists.lisp"
    "${generated}/hash-tables.lisp"
    "${src}/api.lisp"
    "${generated}/methods.lisp"
    "${src}/test-functions.lisp"
    "${src}/derived.lisp"
    "${src}/alias.lisp"
  ];
}
