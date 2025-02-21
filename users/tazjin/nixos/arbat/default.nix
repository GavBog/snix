# arbat is my Unchartevice 6640MA, with a Zhaoxin CPU.
{ depot, lib, pkgs, ... }:

config:
let
  mod = name: depot.path.origSrc + ("/ops/modules/" + name);
  usermod = name: depot.path.origSrc + ("/users/tazjin/nixos/modules/" + name);

  zdevice = device: {
    inherit device;
    fsType = "zfs";
  };
in
{
  imports = [
    (usermod "chromium.nix")
    (usermod "desktop.nix")
    (usermod "fonts.nix")
    (usermod "home-config.nix")
    (usermod "laptop.nix")
    (usermod "persistence.nix")
    (usermod "physical.nix")
    ((pkgs.srcOnly pkgs.home-manager) + "/nixos")
  ];

  tvl.cache.enable = true;

  boot = {
    loader.systemd-boot.enable = true;
    supportedFilesystems = [ "zfs" ];
    zfs.devNodes = "/dev/";
    # TODO: double-check this list
    initrd.availableKernelModules = [ "ahci" "uhci_hcd" "ehci_pci" "xhci_pci" "usb_storage" "sd_mod" "rtsx_usb_sdmmc" ];
    kernelModules = [ "kvm-intel" ]; # interesting
  };

  networking = {
    hostName = "arbat";
    hostId = "864f050b";
    networkmanager.enable = true;
  };

  fileSystems = {
    "/" = zdevice "zpool/ephemeral/root";
    "/home" = zdevice "zpool/ephemeral/home";
    "/persist" = zdevice "zpool/persistent/data" // { neededForBoot = true; };
    "/nix" = zdevice "zpool/persistent/nix";
    "/depot" = zdevice "zpool/persistent/depot";

    "/boot" = {
      device = "/dev/disk/by-uuid/B3B5-92F7";
      fsType = "vfat";
    };
  };

  hardware = {
    enableRedistributableFirmware = true;
    graphics.enable = true;
    bluetooth.enable = true;
  };

  # TODO(tazjin): decide on this
  services.libinput = {
    enable = true;
    # libinput thinks the touchpad is a mouse
    mouse.naturalScrolling = false;
    mouse.disableWhileTyping = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "24.11";
}
