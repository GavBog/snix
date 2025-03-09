{ depot, pkgs, ... }:

depot.nix.buildLisp.library {
  name = "cl-date-time-parser";

  srcs = [
    "${pkgs.srcOnly pkgs.sbcl.pkgs.cl-date-time-parser}/date-time-parser.lisp"
  ];

  deps = [
    depot.third_party.lisp.alexandria
    depot.third_party.lisp.anaphora
    depot.third_party.lisp.split-sequence
    depot.third_party.lisp.cl-ppcre
    depot.third_party.lisp.local-time
    depot.third_party.lisp.parse-float
  ];
}
