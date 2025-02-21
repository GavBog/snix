# Shared home configuration for all machines.

{ depot, pkgs, ... }: # readTree
{ config, lib, ... }: # home-manager


let
  inherit (depot.third_party) chicago95;

  # URL handler to open `tg://` URLs in telega.el
  telega-launcher = pkgs.writeShellScriptBin "telega-launcher" ''
    echo "Opening ''${1} in telega.el ..."
    ${depot.users.tazjin.emacs.emacs}/bin/emacsclient -e "(telega-browse-url \"''${1}\")"
  '';
in
{
  home.activation.screenshots = lib.hm.dag.entryAnywhere ''
    $DRY_RUN_CMD mkdir -p $HOME/screenshots
  '';

  programs.git = {
    enable = true;
    userName = "Vincent Ambo";
    userEmail = "mail@tazj.in";
    extraConfig = {
      pull.rebase = true;
      init.defaultBranch = "canon";
      safe.directory = [ "/depot" ];
    };
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # emacs vterm integration
      source (find '${pkgs.emacsPackages.vterm}' -name 'emacs-vterm.fish')

      # z
      ${pkgs.zoxide}/bin/zoxide init fish | source
    '';
  };

  home.packages = [ telega-launcher ];

  xdg.desktopEntries.telega-launcher = {
    name = "Telega Launcher";
    exec = "${telega-launcher}/bin/telega-launcher";
    terminal = false;
    mimeType = [ "x-scheme-handler/tg" ];
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/tg" = [ "telega-launcher.desktop" ];
      "text/html" = [ "firefox.desktop" ];
      "x-scheme-handler/http" = [ "firefox.desktop" ];
      "x-scheme-handler/https" = [ "firefox.desktop" ];
      "x-scheme-handler/about" = [ "firefox.desktop" ];
      "x-scheme-handler/unknown" = [ "firefox.desktop" ];
    };
  };

  # workaround for https://github.com/nix-community/home-manager/issues/4199
  home.activation.backupWorkaround = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    run rm -f ~/.config/mimeapps.list.backup
  '';

  # put Niri (& related tools) configuration in place
  xdg.configFile."niri/config.kdl".source = depot.users.tazjin.dotfiles.niri;
  xdg.configFile."fuzzel/fuzzel.ini".source = depot.users.tazjin.dotfiles.fuzzel;

  programs.wpaperd = {
    enable = true;
    settings = {
      default = {
        duration = "1d";
        mode = "center";
        sorting = "random";
      };

      any.path = ../wallpapers;
    };
  };

  programs.waybar = {
    enable = true;
    settings = depot.users.tazjin.dotfiles.waybar.config;
    style = depot.users.tazjin.dotfiles.waybar.style;
    systemd.enable = true;
  };
  systemd.user.services.waybar.Unit.After = lib.mkForce [ "niri.service" ];


  services.swayidle = let cmd = "${pkgs.swaylock}/bin/swaylock -fFkl -c 008080"; in {
    enable = true;
    events = [
      { event = "before-sleep"; command = cmd; }
      { event = "lock"; command = cmd; }
    ];
  };
  systemd.user.services.swayidle.Unit.After = lib.mkForce [ "niri.service" ];

  # Enable the dunst notification daemon, but force the
  # configuration file separately instead of going via the strange
  # Nix->dunstrc encoding route.
  services.dunst.enable = true;
  xdg.configFile."dunst/dunstrc" = {
    source = depot.users.tazjin.dotfiles.dunstrc;
    onChange = ''
      ${pkgs.procps}/bin/pkill -u "$USER" ''${VERBOSE+-e} dunst || true
    '';
  };

  gtk = {
    enable = true;
    theme.name = "Chicago95";
    theme.package = chicago95;

    iconTheme.name = "Chicago95-tux";
    iconTheme.package = chicago95;

    cursorTheme.name = lib.mkDefault "Chicago95_Animated_Hourglass_Cursors";
    cursorTheme.package = chicago95;
  };

  systemd.user.startServices = true;

  # Previous default version, see https://github.com/nix-community/home-manager/blob/master/docs/release-notes/rl-2211.adoc
  home.stateVersion = "18.09";
}
