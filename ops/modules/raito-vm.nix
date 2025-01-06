{ lib, config, ... }:
let
  cfg = config.infra.hardware.raito-vm;
  inherit (lib) mkEnableOption mkIf mkOption types;
in
{
  options.infra.hardware.raito-vm = {
    enable = mkEnableOption "Raito's VM hardware defaults";

    networking = {
      nat64.enable = mkEnableOption "the setup of NAT64 rules to the local NAT64 node";

      wan = {
        address = mkOption {
          type = types.str;
          description = "IPv6 prefix for WAN. Ask Raito when in doubt.";
        };
        mac = mkOption {
          type = types.str;
          description = "MAC address for the WAN interface.";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    services.qemuGuest.enable = true;
    systemd.network.enable = true;
    networking.useDHCP = lib.mkDefault false;

    systemd.network.networks."10-wan" = {
      matchConfig.Name = "wan";
      linkConfig.RequiredForOnline = true;
      networkConfig.Address = [ cfg.networking.wan.address ];

      routes = mkIf cfg.networking.nat64.enable [
        {
          Destination = "64:ff9b::/96";
          Gateway = "2001:bc8:38ee:100::100";
          Scope = "site";
        }
      ];

      # Enable DNS64 resolvers from Google, I'm too lazy.
      dns = mkIf cfg.networking.nat64.enable [ "2001:4860:4860::6464" "2001:4860:4860::64" ];
    };

    systemd.network.links."10-wan" = {
      matchConfig.MACAddress = cfg.networking.wan.mac;
      linkConfig.Name = "wan";
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
      "sr_mod"
      "uhci_hcd"
      "virtio_blk"
      "virtio_mmio"
      "virtio_net"
      "virtio_pci"
      "virtio_scsi"
      "xhci_pci"
    ];
  };
}
