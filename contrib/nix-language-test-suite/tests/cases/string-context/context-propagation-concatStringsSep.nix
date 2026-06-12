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
  other-drv = derivation {
    name = "other-fail";
    builder = "/bin/false";
    system = "x86_64-linux";
    outputs = [
      "out"
      "bar"
    ];
  };

  preserveContext = origin: result: builtins.getContext "${result}" == builtins.getContext "${origin}";

  preserveContexts = origins: result: let
    union = builtins.foldl' (x: y: x // y) {} (builtins.map (d: builtins.getContext "${d}") origins);
  in
    union == builtins.getContext "${result}";
in [
  # `concatStringsSep` preserves contexts of both arguments.

  (preserveContexts [drv other-drv] (
    builtins.concatStringsSep "${other-drv}" (
      map toString [
        drv
        drv
        drv
        drv
        drv
      ]
    )
  ))
  (preserveContext drv (
    builtins.concatStringsSep "|" (
      map toString [
        drv
        drv
        drv
        drv
        drv
      ]
    )
  ))
  (preserveContext other-drv (
    builtins.concatStringsSep "${other-drv}" [
      "abc"
      "def"
    ]
  ))
]
