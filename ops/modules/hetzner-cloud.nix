{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
let
  cfg = config.infra.hardware.hetzner-cloud;
  inherit (lib)
    types
    mkOption
    mkEnableOption
    mkIf
    ;
in
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  options.infra.hardware.hetzner-cloud = {
    enable = mkEnableOption "the Hetzner Cloud hardware profile";

    ipv6 = mkOption {
      type = types.str;
    };

    floatingIPs = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
  };

  config = mkIf cfg.enable {
    services.qemuGuest.enable = true;
    systemd.network.enable = true;
    networking.useDHCP = lib.mkDefault false;

    systemd.network.networks."10-wan" = {
      matchConfig.Name = "enp1s0";
      linkConfig.RequiredForOnline = true;
      networkConfig = {
        # DHCPv4 for the IPv4 only.
        DHCP = "ipv4";
        Address = [ cfg.ipv6 ] ++ cfg.floatingIPs;
      };

      routes = [
        {
          Gateway = "fe80::1";
        }
      ];

      dns = [
        "2a01:4ff:ff00::add:1"
        "2a01:4ff:ff00::add:2"
      ];
    };

    boot.loader.systemd-boot.enable = true;

    boot.initrd.kernelModules = [
      "virtio_balloon"
      "virtio_console"
      "virtio_rng"
    ];

    boot.initrd.availableKernelModules = [
      "9p"
      "9pnet_virtio"
      "ata_piix"
      "nvme"
      "sd_mod"
      "sr_mod"
      "uhci_hcd"
      "virtio_blk"
      "virtio_mmio"
      "virtio_net"
      "virtio_pci"
      "virtio_scsi"
      "xhci_pci"
      "ahci"
    ];

    boot.kernelModules = [ ];
    boot.extraModulePackages = [ ];

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  };
}
