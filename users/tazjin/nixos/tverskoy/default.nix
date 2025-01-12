# tverskoy is my Thinkpad X13 AMD 1st gen
{ depot, lib, pkgs, ... }:

config:
let
  quasselClient = pkgs.quassel.override {
    client = true;
    enableDaemon = false;
    monolithic = false;
  };

  mod = name: depot.path.origSrc + ("/ops/modules/" + name);
  usermod = name: depot.path.origSrc + ("/users/tazjin/nixos/modules/" + name);
in
lib.fix (self: {
  imports = [
    (mod "open_eid.nix")
    (usermod "chromium.nix")
    (usermod "desktop.nix")
    (usermod "fonts.nix")
    (usermod "home-config.nix")
    (usermod "laptop.nix")
    (usermod "persistence.nix")
    (usermod "physical.nix")
    (usermod "systemd-unfreeze.nix")

    (pkgs.home-manager.src + "/nixos")
  ] ++ lib.optional (builtins.pathExists ./local-config.nix) ./local-config.nix;

  tvl.cache.enable = true;
  tvl.cache.builderball = true;

  boot = {
    initrd.availableKernelModules = [ "nvme" "ehci_pci" "xhci_pci" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
    initrd.kernelModules = [ ];

    # Restore /home to the blank snapshot, erasing all ephemeral data.
    initrd.postDeviceCommands = lib.mkAfter ''
      zfs rollback -r zpool/ephemeral/home@tazjin-clean
    '';

    # Install thinkpad modules for TLP
    extraModulePackages = [ pkgs.linuxPackages.acpi_call ];

    kernelModules = [ "acpi_call" "kvm-amd" "i2c_dev" ];
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };

  users.users.tazjin.extraGroups = [ "docker" "vboxusers" "adbusers" ];

  fileSystems = {
    "/" = {
      device = "zpool/ephemeral/root";
      fsType = "zfs";
    };

    "/home" = {
      device = "zpool/ephemeral/home";
      fsType = "zfs";
    };

    "/nix" = {
      device = "zpool/local/nix";
      fsType = "zfs";
    };

    "/depot" = {
      device = "zpool/safe/depot";
      fsType = "zfs";
    };

    "/persist" = {
      device = "zpool/safe/persist";
      fsType = "zfs";
      neededForBoot = true;
    };

    # SD card
    "/mnt" = {
      device = "/dev/disk/by-uuid/c602d703-f1b9-4a44-9e45-94dfe24bdaa8";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/BF4F-388B";
      fsType = "vfat";
    };
  };

  hardware = {
    cpu.amd.updateMicrocode = true;
    enableRedistributableFirmware = true;
    bluetooth.enable = true;

    graphics = {
      enable = true;
      enable32Bit = true;

      extraPackages = with pkgs; [
        vaapiVdpau
        libvdpau-va-gl
      ];
    };
  };

  networking = {
    hostName = "tverskoy";
    hostId = "3c91827f";
    domain = "tvl.su";
    useDHCP = false;
    networkmanager.enable = true;
    firewall.enable = false;

    nameservers = [
      "8.8.8.8"
      "8.8.4.4"
    ];
  };

  security.rtkit.enable = true;

  services = {
    tailscale.enable = true;
    printing.enable = true;

    # expose i2c device as /dev/i2c-amdgpu-dm and make it user-accessible
    # this is required for sending control commands to the Dasung screen.
    udev.extraRules = ''
      SUBSYSTEM=="i2c-dev", ACTION=="add", DEVPATH=="/devices/pci0000:00/0000:00:08.1/0000:06:00.0/i2c-5/i2c-dev/i2c-5", SYMLINK+="i2c-amdgpu-dm", TAG+="uaccess"
    '';

    xserver.videoDrivers = [ "amdgpu" ];
  };

  systemd.user.services.lieer-tazjin = {
    description = "Synchronise mail@tazj.in via lieer";
    script = "${pkgs.lieer}/bin/gmi sync";

    serviceConfig = {
      WorkingDirectory = "%h/mail/account.tazjin";
      Type = "oneshot";
    };
  };

  systemd.user.timers.lieer-tazjin = {
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnActiveSec = "1";
      OnUnitActiveSec = "180";
    };
  };

  # android stuff for hacking on Awful.apk
  programs.adb.enable = true;

  system.stateVersion = "20.09";
})
