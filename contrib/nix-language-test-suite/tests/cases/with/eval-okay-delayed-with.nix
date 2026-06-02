# The test checks that delayed `with` evaluation allows overridable self-referential package sets:
#  names introduced by `with pkgs` can refer to the final overridden package set, so mutually
#  dependent packages see overrides correctly
#
# To easier understand the case, here's how execution goes:
#
#   pkgs.a.b.name
#     │
#   pkgs
#     │
#   pkgs_ // (packageOverrides pkgs_)
#     │
#     ├─ `a` comes from pkgs_
#     │
#   pkgs.a
#     │
#   pkgs_.a
#     │
#   derivation {
#     name = "a";
#     inherit b;
#   }
#     │
#   `b` is resolved via `with pkgs`
#     │
#   pkgs.b
#     │
#   (packageOverrides pkgs_).b
#     │
#   derivation (pkgs_.b.drvAttrs // {
#     name = "${pkgs_.b.name}-overridden";
#   })
#     │
#   "b-overridden"
#
let

  pkgs_ = with pkgs; {
    a = derivation {
      name = "a";
      system = builtins.currentSystem;
      builder = "/bin/sh";
      args = [ "-c" "touch $out" ];
      inherit b;
    };

    b = derivation {
      name = "b";
      system = builtins.currentSystem;
      builder = "/bin/sh";
      args = [ "-c" "touch $out" ];
      inherit a;
    };

    c = b;
  };

  packageOverrides = pkgs: with pkgs; {
    b = derivation (b.drvAttrs // { name = "${b.name}-overridden"; });
  };

  pkgs = pkgs_ // (packageOverrides pkgs_);

in "${pkgs.a.b.name} ${pkgs.c.name} ${pkgs.b.a.name}"
