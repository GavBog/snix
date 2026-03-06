{ pkgs, lib, ... }:

pkgs.rustPlatform.buildRustPackage {
  name = "addr2line";
  version = "idon't know";
  src = pkgs.fetchCrate {
    crateName = "addr2line";
    version = "0.26.0";
    hash = "sha256-UNtsQKhSBM8hOp9p8r2xeaTASaGm1/H/JiW5TUB7FMA=";
  };
  cargoHash = "sha256-oqPf3iaebsBWYNAzcVId9rCGGVIGMusb26v3yBN0e5g=";
  cargoBuildFlags = [ "--features=bin" ];
}
