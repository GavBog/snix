let
  drv = derivation {
    name = "fail";
    builder = "/bin/false";
    system = "x86_64-linux";
    outputs = [
      "out"
      "foo"
    ];
  };

  noContext = result: builtins.getContext "${result}" == builtins.getContext "contextless";
in [
  # There should be no context in a parsed derivation name.
  (!builtins.any builtins.hasContext (builtins.attrValues (builtins.parseDrvName "${drv.name}")))

  # Nix does not propagate contexts for `match`.
  (!builtins.any builtins.hasContext (builtins.match "(.*)" "${drv}"))

  # `attrNames` will never ever produce context.
  (noContext (
    toString (
      builtins.attrNames {
        a = {};
        b = {};
        c = {};
      }
    )
  ))
]
