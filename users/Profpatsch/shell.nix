# generic shell.nix that can be used for most of my projects here,
# until I figure out a way to have composable shells.
let root = (import ../../. { }); in
{ pkgs ? root.third_party.nixpkgs, depot ? root, ... }:

pkgs.mkShell {

  buildInputs = [
    pkgs.sqlite-interactive
    pkgs.sqlite-utils
    pkgs.haskell-language-server
    pkgs.cabal-install
    (pkgs.haskellPackages.ghcWithHoogle (h: [
      h.async
      h.aeson-better-errors
      h.blaze-html
      h.bencode
      h.conduit-extra
      h.error
      h.monad-logger
      h.pa-field-parser
      h.pa-label
      h.pa-json
      h.pa-pretty
      h.pa-run-command
      h.ihp-hsx
      h.optparse-simple
      h.PyF
      h.foldl
      h.unliftio
      h.xml-conduit
      h.wai
      h.wai-extra
      h.warp
      h.profunctors
      h.semigroupoids
      h.validation-selective
      h.free
      h.cryptonite-conduit
      h.sqlite-simple
      h.hedgehog
      h.http-conduit
      h.http-conduit
      h.wai-conduit
      h.nonempty-containers
      h.deriving-compat
      h.unix
      h.tagsoup
      h.attoparsec
      # h.iCalendar
      h.case-insensitive
      h.hscolour
      h.nicify-lib
      h.hspec
      h.hspec-expectations-pretty-diff
      h.tmp-postgres
      h.postgresql-simple
      h.resource-pool
      h.xmonad-contrib
      h.hs-opentelemetry-sdk
      h.punycode
    ]))

    pkgs.rustup
    pkgs.pkg-config
    pkgs.fuse
    pkgs.postgresql_14
    pkgs.nodejs
    pkgs.ninja
    pkgs.s6
    pkgs.caddy

    (depot.nix.binify {
      name = "nix-run";
      exe = depot.users.Profpatsch.nix-tools.nix-run;
    })
  ];

  DEPOT_ROOT = toString ./../..;
  PROFPATSCH_ROOT = toString ./.;

  WHATCD_RESOLVER_TOOLS = pkgs.linkFarm "whatcd-resolver-tools" [
    {
      name = "pg_format";
      path = "${pkgs.pgformatter}/bin/pg_format";
    }
  ];

  # DECLIB_MASTODON_ACCESS_TOKEN read from `pass` in .envrc.

  RUSTC_WRAPPER =
    let
      wrapperArgFile = libs: pkgs.writeText "rustc-wrapper-args"
        (pkgs.lib.concatStringsSep
          "\n"
          (pkgs.lib.concatLists
            (map
              (lib: [
                "-L"
                "${pkgs.lib.getLib lib}/lib"
              ])
              libs)));
    in
    depot.nix.writeExecline "rustc-wrapper" { readNArgs = 1; } [
      "$1"
      "$@"
      "@${wrapperArgFile [
      depot.third_party.rust-crates.nom
    ]}"
    ];

}
