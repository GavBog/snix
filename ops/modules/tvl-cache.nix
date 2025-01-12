{ config, lib, pkgs, ... }:

{
  options = {
    tvl.cache.enable = lib.mkEnableOption "the TVL binary cache";
    tvl.cache.builderball = lib.mkEnableOption "use experimental builderball cache";
  };

  config = lib.mkIf config.tvl.cache.enable {
    nix.settings = {
      trusted-public-keys = [
        "cache.tvl.su:kjc6KOMupXc1vHVufJUoDUYeLzbwSr9abcAKdn/U1Jk="
      ];

      substituters = [
        (if config.tvl.cache.builderball
        then "https://cache.tvl.fyi"
        else "https://cache.tvl.su")
      ];
    };
  };
}
