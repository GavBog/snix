{ depot, pkgs, lib, ... }:
let

  # fix: https://github.com/NixOS/nixpkgs/pull/352144
  omega-templates = pkgs.stdenv.mkDerivation {
    name = "omega-templates";
    phases = [ "unpackPhase" "installPhase" ];
    src = pkgs.xapian-omega.src;
    installPhase = ''
      mkdir -p $out/share/omega
      mv templates $out/share/omega
    '';
  };

  omega-test = pkgs.stdenv.mkDerivation {
    name = "omega-test";
    phases = [ "installPhase" ];
    installPhase = ''
        mkdir localhost
        ln -sT localhost localhost:8080
        mkdir ./default
        cp -r ${lib.getOutput "doc" pkgs.tipidee}/share/doc/tipidee ./default/tipidee
        cp -r ${lib.getOutput "doc" pkgs.tipidee}/share/doc/tipidee ./localhost/tipidee

        ln -sT ${pkgs.writers.writeText "omega.conf" ''
          database_dir ./omega.db
          log_dir /tmp/omega.log
          template_dir ${omega-templates}/share/omega/templates
        ''} omega.conf

        ${pkgs.tipidee}/bin/tipidee-config -o tipidee.cdb -i ${pkgs.writers.writeText "tipidee.conf" ''
          domain localhost
          cgi /omega
        ''}

      cp ${pkgs.xapian-omega}/lib/xapian-omega/bin/omega ./localhost

      mkdir omega.db
      ${pkgs.xapian-omega}/bin/omindex --db ./omega.db/default --url / ./default

      mkdir -p $out
      cp -r ./* $out
    '';
  };

  run-omega = pkgs.writers.writeBash "run-omega" ''
    cd ${omega-test}
    emptyenv -p \
      ${pkgs.s6-networking}/bin/s6-tcpserver 127.0.0.1 8080 \
      ${pkgs.s6-networking}/bin/s6-tcpserver-access \
      ${pkgs.tipidee}/bin/tipideed -f tipidee.cdb
  '';


in
{
  inherit
    run-omega
    omega-test
    ;
}

