{ depot, pkgs, ... }:

let
  src = pkgs.srcOnly pkgs.sbcl.pkgs.trivial-ldap;
in
depot.nix.buildLisp.library {
  name = "trivial-ldap";

  deps = with depot.third_party.lisp; [
    usocket
    cl-plus-ssl
    cl-yacc
  ];

  srcs = map (f: src + ("/" + f)) [
    "package.lisp"
    "trivial-ldap.lisp"
  ];

  brokenOn = [
    "ecl" # dynamic cffi
  ];
}
