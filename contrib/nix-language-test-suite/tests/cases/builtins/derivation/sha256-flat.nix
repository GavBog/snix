let
  base = {
    name = "foo";
    builder = "/bin/sh";
    system = "x86_64-linux";
    outputHashAlgo = "sha256";
    outputHashMode = "flat";
  };
in [
  (builtins.derivation (base
    // {
      outputHash = "sha256-Q3QXOoy+iN4VK2CflvRulYvPZXYgF0dO7FoF7CvWFTA=";
    })).outPath

  (builtins.derivation (base
    // {
      name = "foo2";
      outputHash = "sha256-Q3QXOoy+iN4VK2CflvRulYvPZXYgF0dO7FoF7CvWFTA=";
    })).outPath
]
