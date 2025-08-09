{ depot, ... }:
{
  package = import ./package.nix;
  module = import ./module.nix;
}
