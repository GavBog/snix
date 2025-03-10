{ depot, pkgs, lib, ... }:

let
  #   bins = depot.nix.getBins pkgs.sqlite ["sqlite3"];

  whatcd-resolver = pkgs.haskellPackages.mkDerivation {
    pname = "whatcd-resolver";
    version = "0.1.0";

    src = depot.users.Profpatsch.exactSource ./. [
      ./whatcd-resolver.cabal
      ./Main.hs
      ./src/WhatcdResolver.hs
      ./src/AppT.hs
      ./src/Bencode.hs
      ./src/MyLabel.hs
      ./src/JsonLd.hs
      ./src/Optional.hs
      ./src/Html.hs
      ./src/Http.hs
      ./src/Transmission.hs
      ./src/Redacted.hs
    ];

    libraryHaskellDepends = [
      depot.users.Profpatsch.my-prelude
      depot.users.Profpatsch.my-webstuff
      pkgs.haskellPackages.pa-prelude
      pkgs.haskellPackages.pa-label
      pkgs.haskellPackages.pa-error-tree
      pkgs.haskellPackages.pa-field-parser
      pkgs.haskellPackages.pa-run-command
      pkgs.haskellPackages.aeson-better-errors
      pkgs.haskellPackages.bencode
      pkgs.haskellPackages.blaze-html
      pkgs.haskellPackages.hs-opentelemetry-sdk
      pkgs.haskellPackages.http-conduit
      pkgs.haskellPackages.http-types
      pkgs.haskellPackages.ihp-hsx
      pkgs.haskellPackages.monad-logger
      pkgs.haskellPackages.resource-pool
      pkgs.haskellPackages.postgresql-simple
      pkgs.haskellPackages.tmp-postgres
      pkgs.haskellPackages.unliftio
      pkgs.haskellPackages.wai-extra
      pkgs.haskellPackages.warp
      pkgs.haskellPackages.punycode
    ];

    isExecutable = true;
    isLibrary = false;
    license = lib.licenses.mit;
  };

  bins = depot.nix.getBins whatcd-resolver [ "whatcd-resolver" ];

in

depot.nix.writeExecline "whatcd-resolver-wrapped" { } [
  "importas"
  "-i"
  "PATH"
  "PATH"
  "export"
  "PATH"
  # TODO: figure out how to automatically migrate to a new postgres version with tmp_postgres (dump?)
  "${pkgs.postgresql_14}/bin:$${PATH}"
  "export"
  "WHATCD_RESOLVER_TOOLS"
  (pkgs.linkFarm "whatcd-resolver-tools" [
    {
      name = "pg_format";
      path = "${pkgs.pgformatter}/bin/pg_format";
    }
  ])
  bins.whatcd-resolver
]

