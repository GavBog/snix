{ pkgs, lib, ... }:

let
  patchesFromDir = dir:
    lib.filter
      (lib.hasSuffix ".patch")
      (lib.mapAttrsToList
        (name: _: dir + "/${name}")
        (builtins.readDir dir));
in

pkgs.plan9port.overrideAttrs (old: {
  patches = old.patches or [ ] ++ patchesFromDir ./.;

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
})
