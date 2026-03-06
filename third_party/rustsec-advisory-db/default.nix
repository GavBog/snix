# RustSec's advisory db for crates
{ pkgs, depot, ... }: (depot.third_party.sources.rustsec-advisory-db { inherit pkgs; }).outPath
