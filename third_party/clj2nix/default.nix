{ pkgs, ... }:

pkgs.callPackage "${
  (pkgs.fetchFromGitHub {
    owner = "hlolli";
    repo = "clj2nix";
    rev = "3d0a38c954c8e0926f57de1d80d357df05fc2f94";
    sha256 = "0y77b988qdgsrp4w72v1f5rrh33awbps2qdgp2wr2nmmi44541w5";
  })
}/clj2nix.nix" { }
