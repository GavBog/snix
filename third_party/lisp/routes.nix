{ depot, pkgs, ... }:

let

  src = pkgs.applyPatches {
    name = "routes-source";
    src = pkgs.srcOnly pkgs.sbcl.pkgs.routes;

    patches = [
      (pkgs.fetchpatch {
        name = "fix-build-with-ccl.patch";
        url = "https://github.com/archimag/cl-routes/commit/2296cdc316ef8e34310f2718b5d35a30040deee0.patch";
        sha256 = "007c19kmymalam3v6l6y2qzch8xs3xnphrcclk1jrpggvigcmhax";
      })
    ];
  };

in
depot.nix.buildLisp.library {
  name = "routes";

  deps = with depot.third_party.lisp; [
    puri
    iterate
    split-sequence
  ];

  srcs = map (f: src + ("/src/" + f)) [
    "package.lisp"
    "uri-template.lisp"
    "route.lisp"
    "mapper.lisp"
  ];
}
