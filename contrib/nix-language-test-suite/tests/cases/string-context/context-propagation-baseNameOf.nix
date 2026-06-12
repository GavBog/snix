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

  preserveContext = origin: result: builtins.getContext "${result}" == builtins.getContext "${origin}";
in [
  # `baseNameOf propagates context of argument
  (preserveContext "${drv}" (builtins.baseNameOf drv))
  (preserveContext "abc" (builtins.baseNameOf "abc"))
]
