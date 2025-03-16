{ pkgs, lib, ... }:

pkgs.stdenv.mkDerivation {
  pname = "snix-docs";
  version = "0.1";

  outputs = [ "out" ];

  src = lib.cleanSource ./.;

  nativeBuildInputs = [
    pkgs.d2
    pkgs.mdbook
    pkgs.mdbook-admonish
    pkgs.mdbook-d2
    pkgs.mdbook-plantuml
    pkgs.plantuml
  ];

  # plantuml wants to create ./.mdbook-plantuml-cache, which fails as $src is r/o.
  # copy all sources elsewhere to workaround.
  buildCommand = ''
    cp -R $src/. .
    mdbook build -d $out
  '';
}
