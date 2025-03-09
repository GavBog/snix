{ depot, pkgs, ... }:

let
  src = pkgs.applyPatches {
    src = pkgs.srcOnly pkgs.sbcl.pkgs.qbase64;

    patches = [
      # qbase64 expects macOS base64
      ./coreutils-base64.patch
    ];
  };

  getSrcs = builtins.map (p: "${src}/${p}");

in

depot.nix.buildLisp.library {
  name = "qbase64";

  srcs = getSrcs [
    "package.lisp"
    "utils.lisp"
    "stream-utils.lisp"
    "qbase64.lisp"
  ];

  deps = [
    depot.third_party.lisp.trivial-gray-streams
    depot.third_party.lisp.metabang-bind
  ];

  tests = {
    name = "qbase64-tests";

    srcs = getSrcs [
      "qbase64-test.lisp"
    ];

    deps = [
      {
        sbcl = depot.nix.buildLisp.bundled "uiop";
        default = depot.nix.buildLisp.bundled "asdf";
      }
      depot.third_party.lisp.fiveam
      depot.third_party.lisp.cl-fad
    ];

    expression = ''
      (fiveam:run! '(qbase64-test::encoder 'qbase64-test::decoder))
    '';
  };
}
