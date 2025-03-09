{ depot, pkgs, ... }:

let
  src = pkgs.applyPatches {
    src = pkgs.srcOnly pkgs.sbcl.pkgs.lass;
    patches = [
      # https://github.com/Shinmera/LASS/pull/22
      (pkgs.fetchpatch {
        name = "lass-fix-ccl-build.patch";
        url = "https://github.com/Shinmera/LASS/commit/957afc830f0517f1053cdd8605af1dc5e457527f.patch";
        sha256 = "06fp0rnqqvai08lr6aldzga2xc9dxdfffrpgs3rha9gp0xmvlz43";
      })
    ];
  };
in
depot.nix.buildLisp.library {
  name = "lass";

  deps = with depot.third_party.lisp; [
    trivial-indent
    trivial-mimes
    cl-base64
    (depot.nix.buildLisp.bundled "asdf")
  ];

  srcs = map (f: src + ("/" + f)) [
    "package.lisp"
    "readable-list.lisp"
    "compiler.lisp"
    "property-funcs.lisp"
    "writer.lisp"
    "lass.lisp"
    "special.lisp"
    "asdf.lisp"
  ];
}
