let
  corepkgs = import <nix/fetchurl.nix>;
in
  builtins.unsafeGetAttrPos "url" (builtins.functionArgs corepkgs)
