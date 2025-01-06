let
  disk = "/dev/sda";
  targetFsType = "xfs";
  swapSizeInGb = 8;
in
{
  disko.devices = {
    disk = {
      ${disk} = {
        device = "${disk}";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              priority = 100;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            PRIMARY = {
              # Take the next available range.
              start = "0";
              end = "-${toString swapSizeInGb}G";
              content = {
                type = "lvm_pv";
                vg = "vg_${targetFsType}";
              };
            };
            SWAP = {
              # Start from the SWAP area.
              start = "-${toString swapSizeInGb}G";
              size = "100%";
              content = {
                type = "swap";
              };
            };
          };
        };
      };
    };
    lvm_vg = {
      "vg_${targetFsType}" = {
        type = "lvm_vg";
        lvs = {
          ROOT = {
            name = "ROOT";
            size = "2G";
            content = {
              type = "filesystem";
              format = targetFsType;
              mountpoint = "/";
            };
          };
          NIX = {
            name = "NIX";
            size = "40%FREE";
            content = {
              type = "filesystem";
              format = targetFsType;
              mountpoint = "/nix";
              mountOptions = [ "noatime" ];
            };
          };
          VAR = {
            name = "VAR";
            size = "100%FREE";
            content = {
              type = "filesystem";
              format = targetFsType;
              mountpoint = "/var";
              mountOptions = [ "noatime" ];
            };
          };
        };
      };
    };
  };
}
