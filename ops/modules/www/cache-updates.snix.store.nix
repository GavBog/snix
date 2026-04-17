{ ... }:
{
  imports = [
    ./base.nix
  ];

  services.nginx.virtualHosts."cache-updates.snix.store" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      extraConfig = ''
        return 200 'thanks!';
      '';
    };
  };
}
