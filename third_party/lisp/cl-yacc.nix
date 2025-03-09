{ depot, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "jech";
    repo = "cl-yacc";
    rev = "1812e05317dcab1e97905625c018c043d71f9187"; # 2023-01-08
    sha256 = "1f974ysi7mlrksnqg63iwwxgbypkng4n240q29imkrz6m5pwdig7";
  };
in
depot.nix.buildLisp.library {
  name = "cl-yacc";

  srcs = map (f: src + ("/" + f)) [
    "yacc.lisp"
  ];
}
