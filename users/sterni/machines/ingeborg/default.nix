{ config, lib, pkgs, depot, ... }:

{
  imports = [
    # Third party modules
    "${depot.third_party.agenix.src}/modules/age.nix"
    # Basic settings
    ../../modules/common.nix
    # These modules touch things related to booting (filesystems, initrd network…)
    ./hardware.nix
    ./network.nix
    # (More or less) pluggable service configuration
    (depot.path.origSrc + "/ops/modules/btrfs-auto-scrub.nix")
    ./monitoring.nix
    ./minecraft.nix
    ./http/sterni.lv.nix
    ./http/code.sterni.lv.nix
    ./http/flipdot.openlab-augsburg.de.nix
    ./tv.nix
    ./quassel.nix

    # Inactive:
    # ./http/likely-music.sterni.lv.nix

    # TODO(sterni): fail2ban
    # TODO(sterni): automatic backups for full recovery
  ];

  config = {
    system.stateVersion = "24.05";
  };
}
