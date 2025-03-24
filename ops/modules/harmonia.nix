{ config, depot, ... }:

{
  age.secrets.binary-cache-key.file = depot.ops.secrets."binary-cache-key.age";

  services.harmonia = {
    enable = true;
    signKeyPaths = [ config.age.secrets.binary-cache-key.path ];
    # Set priority to be slightly lower than cache.nixos.org.
    # This makes it so we only substitute from our binary cache stuff that's not in cache.nixos.org.
    settings.priority = 41;
  };
}
