{ pkgs, ... }:

pkgs.stdenv.mkDerivation {
  name = "deploy-machine";

  phases = [ "installPhase" "installCheckPhase" ];

  nativeBuildInputs = with pkgs; [
    makeWrapper
  ];

  installPhase = ''
    mkdir -p $out/bin
    makeWrapper ${./deploy-machine.sh} $out/bin/deploy-machine.sh \
      --prefix PATH : ${with pkgs; lib.makeBinPath [
        ansi2html
        git
        jq
        nvd
      ]}
  '';

  installCheckInputs = with pkgs; [
    shellcheck
  ];

  doInstallCheck = true;
  installCheckPhase = ''
    shellcheck $out/bin/deploy-machine.sh
  '';
}
