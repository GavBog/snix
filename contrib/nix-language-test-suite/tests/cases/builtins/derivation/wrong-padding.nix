(builtins.derivation {
  name = "foo";
  builder = "/bin/sh";
  system = "x86_64-linux";
  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = "sha256-fgIr3TyFGDAXP5+qoAaiMKDg/a1MlT6Fv/S/DaA24S8====";
}).outPath
