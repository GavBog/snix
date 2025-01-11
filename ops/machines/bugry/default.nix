{ depot, lib, pkgs, ... }: # readTree options
{ config, ... }: # passed by module system

let
  mod = name: depot.path.origSrc + ("/ops/modules/" + name);
in
{
  imports = [
    (mod "tvl-cache.nix")
    (mod "tvl-users.nix")
  ];

  hardware.cpu.intel.updateMicrocode = true;

  boot = {
    tmp.useTmpfs = true;
    kernelModules = [ "kvm-intel" ];
    supportedFilesystems = [ "zfs" ];
    kernelParams = [
      "ip=91.199.149.239::91.199.149.1:255.255.255.0:bugry:enp6s0:none"
    ];

    initrd = {
      availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" "e1000e" ];

      # initrd SSH for disk unlocking
      network = {
        enable = true;
        ssh = {
          enable = true;
          port = 2222;
          authorizedKeys =
            depot.users.tazjin.keys.all
            ++ depot.users.lukegb.keys.all
            ++ depot.users.sterni.keys.all;

          hostKeys = [
            /etc/secrets/initrd_host_ed25519_key
          ];
        };

        # this will launch the zfs password prompt on login and kill the
        # other prompt
        postCommands = ''
          echo "zfs load-key -a && killall zfs" >> /root/.profile
        '';
      };
    };

    kernel.sysctl = {
      "net.ipv4.tcp_congestion_control" = "bbr";
    };

    loader.grub = {
      enable = true;
      device = "/dev/disk/by-id/wwn-0x5002538ec0ae4c93";
    };

    zfs.requestEncryptionCredentials = true;
  };

  fileSystems = {
    "/" = {
      device = "tank/root";
      fsType = "zfs";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/70AC-4B48";
      fsType = "vfat";
    };

    "/nix" = {
      device = "tank/nix";
      fsType = "zfs";
    };

    "/home" = {
      device = "tank/home";
      fsType = "zfs";
    };
  };

  networking = {
    hostName = "bugry";
    domain = "tvl.fyi";
    hostId = "8425e349";
    useDHCP = false;

    interfaces.enp6s0.ipv6.addresses = [{
      address = "91.199.149.239";
      prefixLength = 24;
    }];

    defaultGateway = "91.199.149.1";

    nameservers = [
      "8.8.8.8"
      "8.8.4.4"
    ];

    firewall.allowedTCPPorts = [ 22 80 443 ];
  };

  # Generate an immutable /etc/resolv.conf from the nameserver settings
  # above (otherwise DHCP overwrites it):
  environment.etc."resolv.conf" = with lib; {
    source = pkgs.writeText "resolv.conf" ''
      ${concatStringsSep "\n" (map (ns: "nameserver ${ns}") config.networking.nameservers)}
      options edns0
    '';
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  services.fail2ban.enable = true;

  programs.mtr.enable = true;
  programs.mosh.enable = true;

  time.timeZone = "UTC";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Join TVL Tailscale network at net.tvl.fyi
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
  };

  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
    }
  ];

  zramSwap.enable = true;

  system.stateVersion = "24.11";
}
