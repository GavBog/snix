{ pkgs, lib, ... }:

let
  inherit (pkgs) llvmPackages;
  drv = llvmPackages.stdenv.mkDerivation {
    name = "blipqn";

    src = lib.cleanSource ./.;

    makeFlags = [ "PREFIX=$(out)" ];

    nativeBuildInputs = [
      llvmPackages.clang-tools
    ];

    buildInputs = [
      pkgs.cbqn
    ];

    passthru.debug = drv.overrideAttrs (old: {
      CFLAGS = "-g -Werror";
    });
  };
in

drv
