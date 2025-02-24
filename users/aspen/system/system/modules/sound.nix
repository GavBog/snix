{ config, lib, pkgs, ... }:

{
  # Enable sound.
  services.pulseaudio.enable = true;
  services.pipewire.enable = false;

  environment.systemPackages = with pkgs; [
    pulseaudio-ctl
    paprefs
    pasystray
    pavucontrol
  ];

  services.pulseaudio.package = pkgs.pulseaudioFull;
}
