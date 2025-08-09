{
  depot,
  pkgs,
  lib,
  ...
}:
{ gerrit }:

let
  classPath = lib.concatStringsSep ":" [
    "${gerrit}/share/api/extension-api_deploy.jar"
  ];
in
pkgs.stdenvNoCC.mkDerivation rec {
  name = "${pname}-${version}.jar";
  pname = "gerrit-tvl";
  version = "0.0.1";

  src = ./.;

  nativeBuildInputs = with pkgs; [
    jdk
  ];

  buildPhase = ''
    mkdir $NIX_BUILD_TOP/build

    # Build Java components.
    export JAVAC="javac -cp ${classPath} -d $NIX_BUILD_TOP/build --release 11"
    $JAVAC ./HttpModule.java

    # Install static files.
    cp -R static $NIX_BUILD_TOP/build/static
  '';

  installPhase = ''
    jar --create --file $out --manifest $src/MANIFEST.MF -C $NIX_BUILD_TOP/build .
  '';
}
