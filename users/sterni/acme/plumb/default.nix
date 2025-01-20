{ pkgs, lib, ... }:

pkgs.stdenvNoCC.mkDerivation {
  name = "sterni-plumb";

  src = builtins.path {
    path = ./.;
    filter = path: _: !(lib.hasSuffix "default.nix" path);
  };

  dontConfigure = true;
  dontBuild = true;

  # The write will fail if there's something wrong with the rules,
  # though it only detects some problems.
  checkPhase = ''
    runHook preInstall
    export NAMESPACE="$(mktemp -d)"
    9 plumber -f &
    pid="$!"
    until [[ -e "$NAMESPACE/plumb" ]]; do
      sleep 0.1
    done
    9 9p write plumb/rules < sterni.plumbing
    kill "$pid"
    runHook postInstall
  '';
  doCheck = true;
  checkInputs = [
    pkgs.plan9port
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    mv * "$out/"
    runHook postInstall
  '';
}
