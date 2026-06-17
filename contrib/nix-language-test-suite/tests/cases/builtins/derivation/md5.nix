[
  (builtins.derivation {
    name = "foo";
    builder = "/bin/sh";
    system = "x86_64-linux";
    outputHashMode = "recursive";
    outputHashAlgo = "md5";
    outputHash = "md5-07BzhNET7exJ6qYjitX/AA==";
  }).outPath

  (builtins.derivation {
    name = "foo";
    builder = "/bin/sh";
    system = "x86_64-linux";
    outputHashMode = "flat";
    outputHashAlgo = "md5";
    outputHash = "md5-07BzhNET7exJ6qYjitX/AA==";
  }).outPath
]
