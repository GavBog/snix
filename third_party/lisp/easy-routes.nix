{ depot, pkgs, ... }:

let

  src = pkgs.srcOnly pkgs.sbcl.pkgs.easy-routes;
in

depot.nix.buildLisp.library {
  name = "easy-routes";
  deps = with depot.third_party.lisp; [
    hunchentoot
    routes
  ];

  srcs = map (f: src + ("/" + f)) [
    "package.lisp"
    "util.lisp"
    "easy-routes.lisp"
    "routes-map-printer.lisp"
  ];

  brokenOn = [
    "ecl" # dynamic cffi
  ];
}
