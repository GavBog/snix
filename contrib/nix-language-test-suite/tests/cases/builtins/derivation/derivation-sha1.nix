[
  (builtins.derivation {
    name = "foo";
    builder = "/bin/sh";
    system = "x86_64-linux";
    outputHashMode = "recursive";
    outputHashAlgo = "sha1";
    outputHash = "sha1-VUCRC+16gU5lcrLYHlPSUyx0Y/Q=";
  }).outPath

  (builtins.derivation {
    name = "foo";
    builder = "/bin/sh";
    system = "x86_64-linux";
    outputHashMode = "flat";
    outputHashAlgo = "sha1";
    outputHash = "sha1-VUCRC+16gU5lcrLYHlPSUyx0Y/Q=";
  }).outPath
]
