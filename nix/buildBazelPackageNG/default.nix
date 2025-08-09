{ pkgs, ... }:

(pkgs.callPackage ./buildBazelPackageNG.nix { })
// {
  bazelRulesJavaHook = pkgs.callPackage ./bazelRulesJavaHook { };
  bazelRulesNodeJS5Hook = pkgs.callPackage ./bazelRulesNodeJS5Hook { };
}
