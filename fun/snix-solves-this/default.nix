{ pkgs, ... }:

pkgs.runCommand "webroot" { } ''
  mkdir -p $out
  cp ${./index.html} $out/index.html
  cp ${./snix_solves_this.png} $out/snix-solves-this.png
''
