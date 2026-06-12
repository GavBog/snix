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

  preserveContexts = origins: result: let
    union = builtins.foldl' (x: y: x // y) {} (builtins.map (d: builtins.getContext "${d}") origins);
  in
    union == builtins.getContext "${result}";
in [
  # `toJSON` preserves context of its inputs.
  (preserveContexts [drv other-drv] (
    builtins.toJSON {
      a = [drv];
      b = [other-drv];
    }
  ))
  (preserveContexts [drv other-drv] (
    builtins.toJSON {
      a.deep = [drv];
      b = [other-drv];
    }
  ))
  (preserveContexts [drv other-drv] (
    builtins.toJSON {
      a = "${drv}";
      b = [other-drv];
    }
  ))
  (preserveContexts [drv other-drv] (
    builtins.toJSON {
      a.deep = "${drv}";
      b = [other-drv];
    }
  ))
  (preserveContexts [drv other-drv] (
    builtins.toJSON {
      a = "${drv} ${other-drv}";
    }
  ))
  (preserveContexts [drv other-drv] (
    builtins.toJSON {
      a.b.c.d.e.f = "${drv} ${other-drv}";
    }
  ))
]
