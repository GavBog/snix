{ depot, lib, pkgs, ... }:

let
  bins = depot.nix.getBins pkgs.nq [ "nqtail" "nq" ];

  machines = lib.mapAttrs
    (name: _:
      depot.ops.nixos.nixosFor (import (./. + ("/" + name)))
    )
    (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./.));

  # TODO(sterni): share code with rebuild-system
  localDeployScriptFor = { system, config, ... }:
    pkgs.writeShellScript "local-deploy-${system.name}" ''
      set -eu
      if [[ "$(hostname)" != "${config.networking.hostName}" ]]; then
        echo "$0: unexpected hostname: $(hostname). Are you deploying on the right machine?"
        exit 1
      fi
      nix-env -p /nix/var/nix/profiles/system --set "${system}"
      "${system}/bin/switch-to-configuration" switch
    '';

  # Builds the system on the remote machine
  deployScriptFor = { system, ... }@machine:
    pkgs.writeShellScript "remote-deploy-${system.name}" ''
      set -eu

      if [ $# != 1 ]; then
        printf 'usage: %s [USER@]HOST' "$0"
        exit 100
      fi

      readonly TARGET_HOST="$1"
      readonly DEPLOY_DRV="${
        builtins.unsafeDiscardOutputDependency (
          # Wrapper script around localDeployScriptFor that merely starts the
          # local deploy script using and nq and then waits using nqtail. This means
          # we can't Ctrl-C the deploy and it won't be terminated by a lost
          # connection.
          pkgs.writeShellScript "queue-deploy-${system.name}" ''
            readonly STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/sterni-deploy"
            mkdir -p "$STATE_DIR"

            export NQDIR="$STATE_DIR"

            "${bins.nq}" "${localDeployScriptFor machine}"
            "${bins.nqtail}"
          ''
        ).drvPath
      }"

      nix-copy-closure -s --gzip --to "$TARGET_HOST" "$DEPLOY_DRV"

      readonly DEPLOY_OUT="$(ssh "$TARGET_HOST" "nix-store -r '$DEPLOY_DRV'")"

      ssh "$TARGET_HOST" "$DEPLOY_OUT"
    '';

in

depot.nix.readTree.drvTargets (
  # this somehow becomes necessarily ugly with nixpkgs-fmt
  machines // { inherit deployScriptFor; } //

  lib.mapAttrs'
    (name: _: {
      name = "${name}System";
      value = machines.${name}.system;
    })
    machines

    //

  lib.mapAttrs'
    (name: _: {
      name = "${name}Deploy";
      value = deployScriptFor machines.${name};
    })
    machines
)
