{ depot, modulesPath, config, lib, pkgs, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../modules/common.nix
    ../modules/laptop.nix
    ../modules/xserver.nix
    ../modules/fonts.nix
    ../modules/sound.nix
    ../modules/tvl.nix
    ../modules/development.nix
  ];

  networking.hostName = "yeren";

  system.stateVersion = "21.03";

  time.timeZone = "America/New_York";

  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  boot = {
    initrd = {
      availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
      kernelModules = [ ];

      luks.devices = {
        "cryptroot".device = "/dev/disk/by-uuid/dcfbc22d-e0d2-411b-8dd3-96704d3aae2e";
      };
    };

    # TODO(aspen): remove after https://github.com/NixOS/nixpkgs/pull/378830/
    kernelPackages = pkgs.linuxKernel.packages.linux_6_11;

    kernelModules = [ "kvm-intel" ];
    blacklistedKernelModules = [ "psmouse" ];
    extraModulePackages = [
      config.boot.kernelPackages.digimend
    ];
    kernelParams = [
      "i915.preliminary_hw_support=1"
      "pcie_aspm=force"
    ];

    # https://bbs.archlinux.org/viewtopic.php?pid=1933643#p1933643
    extraModprobeConfig = ''
      options snd-intel-dspcfg dsp_driver=1
    '';

    kernel.sysctl = {
      "kernel.perf_event_paranoid" = -1;
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/53A9-248B";
      fsType = "vfat";
    };
  };

  swapDevices = [{
    device = "/dev/disk/by-uuid/b627cb0e-0451-4f25-94d0-6497e01f0da4";
  }];

  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
  };

  services.xserver = {
    exportConfiguration = true;
    extraConfig = ''
      Section "Device"
        Identifier  "Intel Graphics"
        Driver      "intel"
        Option      "TripleBuffer" "true"
        Option      "TearFree"     "true"
        Option      "DRI"          "true"
        Option      "AccelMethod"  "sna"
      EndSection
    '';
  };

  hardware.firmware = with pkgs; [
    alsa-firmware
    sof-firmware
  ];

  hardware.graphics.extraPackages = with pkgs; [
    vaapiIntel
    vaapiVdpau
    libvdpau-va-gl
    intel-media-driver
  ];

  # Disabled for now until libfprint-tod can get a version bump
  # services.fprintd = {
  #   enable = true;
  #   package = pkgs.fprintd-tod;
  # };

  systemd.services.fprintd.environment.FP_TOD_DRIVERS_DIR =
    "${pkgs.libfprint-2-tod1-goodix}/usr/lib/libfprint-2/tod-1";

  security.pam.services = {
    login.fprintAuth = true;
    sudo.fprintAuth = true;
    i3lock.fprintAuth = false;
    i3lock-color.fprintAuth = false;
    lightdm.fprintAuth = true;
    lightdm-greeter.fprintAuth = true;
  };

  hardware.graphics.enable32Bit = true;

  hardware.pulseaudio.extraConfig = ''
    load-module module-remap-source source_name=KompleteAudio6_1 source_properties=device.description=KompleteAudio6Input1 master=alsa_input.usb-Native_Instruments_Komplete_Audio_6_458E0FFD-00.multichannel-input remix=no channels=1 master_channel_map=front-left channel_map=mono
    load-module module-remap-source source_name=KompleteAudio6_2 source_properties=device.description=KompleteAudio6Input2 master=alsa_input.usb-Native_Instruments_Komplete_Audio_6_458E0FFD-00.multichannel-input remix=no channels=1 master_channel_map=front-right channel_map=mono
    load-module module-remap-sink sink_name=KompleteAudio6_12 sink_properties=device.description=KompleteAudio6_12 remix=no master=alsa_output.usb-Native_Instruments_Komplete_Audio_6_458E0FFD-00.analog-surround-21 channels=2 master_channel_map=front-left,front-right channel_map=front-left,front-right
  '';

  services.fwupd.enable = true;

  services.tailscale.enable = true;
}
