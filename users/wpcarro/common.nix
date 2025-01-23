{ depot, pkgs, ... }:

let
  inherit (depot.users) wpcarro;
in
{
  programs = {
    fish.enable = true;

    gnupg.agent.enable = true;

    ssh = {
      startAgent = true;
      extraConfig = ''
        AddKeysToAgent yes
      '';
    };

    git = {
      enable = true;
      config = {
        user.name = "William Carroll";
        user.email = "wpcarro@gmail.com";
      };
    };
  };

  services = {
    # Remodel the system clipboard as a list instead of a point.
    clipmenu.enable = true;

    # TODO(wpcarro): broken in nixpkgs as of 2023-10-04
    locate.enable = false;

    depot.automatic-gc = {
      enable = true;
      interval = "1 hour";
      diskThreshold = 16; # GiB
      maxFreed = 10; # GiB
      preserveGenerations = "14d";
    };
  };

  # Command-line tools I commonly used and want available on most (or all) of my
  # machines.
  shell-utils = with pkgs; [
    age
    bat
    coreutils
    direnv
    diskus
    emacs
    fd
    fzf
    git
    gnupg
    htop
    jq
    nmap
    passage
    python3
    rink
    ripgrep
    tldr
    tokei
    tree
    vim
    whois
    # TODO(wpcarro): Debug this failing build.
    # wpcarro.tools.simple_vim
    xclip
    zip
  ] ++
  (if pkgs.stdenv.isLinux then [
    mkpasswd
    sysz
    # This depends on compiler-rt-libc-10.0.1, which is marked as broken on
    # aarch64-darwin, but depot sets `allowBroken = true`, which means any
    # build that depends on dig will fail on OSX (e.g. emacs).
    # https://github.com/NixOS/nixpkgs/blob/e9b195248c6cd7961a453b10294aea9ab58e01b4/pkgs/development/compilers/llvm/10/compiler-rt/default.nix#L122
    dig
  ] else [ ]);
}
