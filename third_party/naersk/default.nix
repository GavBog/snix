{ depot, pkgs, ... }:

pkgs.callPackage (import depot.third_party.sources.naersk) { }
