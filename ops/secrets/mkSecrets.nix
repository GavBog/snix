# Expose secrets as part of the tree, exposing their paths at eval time.
#
# Note that encrypted secrets end up in the Nix store, but this is
# fine since they're publicly available anyways.
{ depot, lib, ... }:

(
  path: secrets:
  depot.nix.readTree.drvTargets
    # Import each secret into the Nix store
    (builtins.mapAttrs (name: _: "${path}/${name}") secrets)
)
