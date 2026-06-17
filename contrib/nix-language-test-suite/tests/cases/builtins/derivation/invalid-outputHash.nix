(builtins.derivation {
  name = "foo";
  builder = "/bin/sh";
  system = "x86_64-linux";
  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = "sha256-00";
}).outPath
