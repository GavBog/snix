# Experimental Nix Static Website Authoring Tool
#
# Proof of Concept for a Nix library that allows for authoring static websites
# in Nix in a relatively ad hoc way, i.e. no specific markup or structure
# requirements. In particular, the library can help with creating relative
# references between files/pages so that the website is fully relocatable via
# (relativeToRoot). I use this for fairly trivial websites at the moment though
# I'm not happy with the relative linking feature yet. The API is probably going
# to be redesigned to improve this—you have been warned.
{ depot, pkgs, lib, ... }:

# TODO(sterni): implement generic deploy script
# TODO(sterni): port orgPage to depot
# TODO(sterni): replace relativeToRoot with a fixpoint that exposes (relative) urls
let
  inherit (lib)
    isDerivation
    ;

  inherit (depot.nix)
    writeTree
    utils
    ;

  minify = type: file: pkgs.runCommandNoCC (utils.storePathName file)
    {
      nativeBuildInputs = [ pkgs.buildPackages.minify ];
      env = { inherit file; };
    }
    ''
      minify --type ${type} < "$file" > "$out"
    '';

  makeWebsite = name: { args ? { } }: tree:
    let
      callTree = relativeToRoot: tree:
        if builtins.isFunction tree then
          tree (args // { inherit relativeToRoot; })
        else if builtins.isAttrs tree && !(isDerivation tree) then
          builtins.mapAttrs (_: v: callTree "${relativeToRoot}../" v) tree
        else
          tree;
    in
    writeTree name (builtins.mapAttrs (_: callTree "") tree);
in

{
  __functor = _: makeWebsite;
  inherit makeWebsite minify;
}
