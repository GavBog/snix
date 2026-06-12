# Check that various types interpolate with context
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
  a-path-drv = builtins.path {
    name = "a-path-drv";
    path = ./hello.txt;
  };
  another-path-drv = builtins.filterSource (_: true) ./hello.txt;
in [
  # `toFile` should produce context.
  (builtins.hasContext "${(builtins.toFile "myself" "${./hello.txt}")}")

  # `derivation` should produce context.
  (builtins.hasContext "${drv}")

  # `builtins.path` / `builtins.filterSource` should produce context.
  (builtins.hasContext "${a-path-drv}")
  (builtins.hasContext "${another-path-drv}")
]
