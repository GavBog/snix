let
  # Construct two derivations with the same parameters except one of them lost a context string
  # for a dependency, causing the loss of an element in the `inputDrvs` derivation. Therefore,
  # making `outPath` different.
  dep1 = builtins.derivation {
    name = "foo";
    builder = "/bin/sh";
    system = "x86_64-linux";
  };

  drv11 = builtins.derivation {
    name = "foo";
    builder = "/bin/sh";
    system = "x86_64-linux";
    env = "${dep1}";
  };
  drv12 = builtins.derivation {
    name = "foo";
    builder = "/bin/sh";
    system = "x86_64-linux";
    env = "${builtins.unsafeDiscardStringContext dep1}";
  };

  # Construct an attribute set that coerces to a derivation and verify that the return type is
  # a string.
  dep2 = builtins.derivation {
    name = "foo";
    builder = "/bin/sh";
    system = "x86_64-linux";
  };
  attr2 = {__toString = _: dep2;};
in [
  drv11.outPath
  drv12.outPath

  (builtins.typeOf (builtins.unsafeDiscardStringContext attr2) == "string")
]
