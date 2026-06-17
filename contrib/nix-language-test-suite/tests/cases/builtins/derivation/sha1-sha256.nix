(builtins.derivation {
  name = "foo";
  builder = "/bin/sh";
  system = "x86_64-linux";
  outputHashMode = "recursive";
  outputHashAlgo = "sha1";
  outputHash = "sha256-Q3QXOoy+iN4VK2CflvRulYvPZXYgF0dO7FoF7CvWFTA=";
}).outPath
