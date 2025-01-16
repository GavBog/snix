# This module is common in the weakest sense, i.e. contains common settings to
# all my machines contained in depot—as opposed to common to all my potential
# machines. Consequently, this module is currently very server-centric.
{ pkgs, lib, depot, config, ... }:

let
  me = "lukas";
in

{
  config = {

    # More common

    time.timeZone = "Europe/Berlin";

    nix = {
      package = pkgs.nix_2_3;
      settings = {
        trusted-public-keys = lib.mkAfter [
          "headcounter.org:/7YANMvnQnyvcVB6rgFTdb8p5LG1OTXaO+21CaOSBzg="
        ];
        substituters = lib.mkAfter [
          "https://hydra.build"
        ];
        trusted-users = [ me ];
      };
    };
    tvl.cache.enable = true;

    programs.fish.enable = true;

    users = {
      users = {
        root.openssh.authorizedKeys.keys = depot.users.sterni.keys.all;
        ${me} = {
          isNormalUser = true;
          extraGroups = [ "wheel" "http" "git" ];
          openssh.authorizedKeys.keys = depot.users.sterni.keys.all;
          shell = pkgs.fish;
        };
      };
    };

    # Less common

    services = {
      journald.extraConfig = ''
        SystemMaxUse=10G
      '';

      openssh.enable = true;
      # TODO(sterni): consider porting to reaction
      fail2ban.enable = true;
    };

    programs = {
      mosh.enable = true;
      tmux.enable = true;
    };

    environment.systemPackages = [
      pkgs.wget
      pkgs.git
      pkgs.stow
      pkgs.htop
      pkgs.foot.terminfo
      pkgs.vim
      pkgs.smartmontools
    ];

    security.acme = {
      defaults.email = builtins.getAttr "email" (
        builtins.head (
          builtins.filter (attrs: attrs.username == "sterni") depot.ops.users
        )
      );
      acceptTerms = true;
    };
  };
}
