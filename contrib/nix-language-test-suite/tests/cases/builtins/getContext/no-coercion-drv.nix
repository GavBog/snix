# Verify that getContext does not coerce to string
let
  drv = builtins.derivation {
    name = "foo";
    system = "x86_64-linux";
    builder = "/bin/sh";
  };
in
  builtins.getContext drv
