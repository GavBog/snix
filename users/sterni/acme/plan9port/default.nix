{ pkgs, lib, ... }:

let
  patchesFromDir = dir:
    lib.filter
      (lib.hasSuffix ".patch")
      (lib.mapAttrsToList
        (name: _: dir + "/${name}")
        (builtins.readDir dir));

  mkbqnkeyboard' = pkgs.writeShellScript "mkbqnkeyboard'" ''
    exec ${pkgs.cbqn}/bin/BQN ${../mkbqnkeyboard.bqn} -s -i \
      "${pkgs.srcOnly pkgs.mbqn}/editors/inputrc" "$1"
  '';
in

pkgs.plan9port.overrideAttrs (old: {
  patches = old.patches or [ ] ++ patchesFromDir ./.;
  postPatch = old.postPatch or "" + ''
    ${mkbqnkeyboard'} lib/keyboard

    cp --reflink=auto ${./../plumb}/* plumb/
    mv plumb/sterni.plumbing plumb/initial.plumbing
  '';

  nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
    pkgs.buildPackages.makeWrapper
  ];

  # Make some tools (that don't clash) available in PATH directly
  postInstall = old.postInstall or "" + ''
    for cmd in 9p 9pfuse; do
      makeWrapper "$out/plan9/bin/$cmd" "$out/bin/$cmd" \
        --set PLAN9 "$out/plan9"
    done
  '';

  doInstallCheck = true;
  installCheckPhase = old.installCheckPhase or "" + ''
    export NAMESPACE="$(mktemp -d)"
    "$out/bin/9" plumber -f &
    pid="$!"
    until [[ -e "$NAMESPACE/plumb" ]]; do
      sleep 0.1
    done
    "$out/bin/9" 9p write plumb/rules < ${./../plumb}/sterni.plumbing
    kill "$pid"
  '';
})
