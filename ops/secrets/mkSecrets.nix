# Expose secrets as part of the tree, exposing their paths at eval time.
#
# Note that encrypted secrets end up in the Nix store, but this is
# fine since they're publicly available anyways.
{ depot, lib, ... }:
let
  types = depot.third_party.korora;
  inherit (lib) hasPrefix isString;

  sshPubkey = types.typedef "SSH pubkey" (s: isString s && hasPrefix "ssh-" s);

  agePubkey = types.typedef "age pubkey" (s: isString s && hasPrefix "age" s);

  agenixSecret = types.struct "agenixSecret" {
    publicKeys = types.listOf (
      types.union [
        sshPubkey
        agePubkey
      ]
    );
  };

in
(
  path: secrets:
  depot.nix.readTree.drvTargets
    # Import each secret into the Nix store
    (builtins.mapAttrs (name: secret: agenixSecret.check secret "${path}/${name}") secrets)
)
