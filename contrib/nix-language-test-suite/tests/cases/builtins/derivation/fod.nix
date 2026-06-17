let
  # Construct two FODs with the same name, and same known output (but
  # slightly different recipe), ensure they have the same output hash.
  drv11 = builtins.derivation {
    name = "foo";
    builder = "/bin/sh";
    system = "x86_64-linux";
    outputHash = "sha256-Q3QXOoy+iN4VK2CflvRulYvPZXYgF0dO7FoF7CvWFTA=";
  };
  drv12 = builtins.derivation {
    name = "foo";
    builder = "/bin/aa";
    system = "x86_64-linux";
    outputHash = "sha256-Q3QXOoy+iN4VK2CflvRulYvPZXYgF0dO7FoF7CvWFTA=";
  };

  # Construct two FODs with different names, and same known output and recipe,
  # ensure they have different output hashes.
  drv21 = builtins.derivation {
    name = "foo";
    builder = "/bin/sh";
    system = "x86_64-linux";
    outputHash = "sha256-Q3QXOoy+iN4VK2CflvRulYvPZXYgF0dO7FoF7CvWFTA=";
  };
  drv22 = builtins.derivation {
    name = "bar";
    builder = "/bin/sh";
    system = "x86_64-linux";
    outputHash = "sha256-Q3QXOoy+iN4VK2CflvRulYvPZXYgF0dO7FoF7CvWFTA=";
  };
in [
  drv11.outPath
  drv12.outPath

  drv21.outPath
  drv22.outPath
]
