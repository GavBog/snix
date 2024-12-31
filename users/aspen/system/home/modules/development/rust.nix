{ config, lib, pkgs, ... }:

let
  inherit (config.lib) depot;
in

with lib;

{

  home.packages = with pkgs; [
    rustup

    cargo-bloat
    cargo-edit
    cargo-expand
    cargo-hakari
    cargo-nextest
    cargo-udeps
    sccache
    evcxr

    # benchmarking+profiling
    cargo-criterion
    cargo-flamegraph
    inferno
    hotspot
  ] ++ optionals (stdenv.isLinux) [
    cargo-rr
  ];

  programs.zsh.shellAliases = {
    "cg" = "cargo";
    "cb" = "cargo build";
    "ct" = "cargo test";
    "ctw" = "fd -e rs | entr cargo test";
    "cch" = "cargo check";
  };

  home.file.".cargo/config".text = ''
    [build]
    rustc-wrapper = "${pkgs.sccache}/bin/sccache"

    [target.x86_64-unknown-linux-gnu]
    linker = "clang"
    rustflags = ["-C", "link-arg=-fuse-ld=${pkgs.mold}/bin/mold"]
  '';
}
