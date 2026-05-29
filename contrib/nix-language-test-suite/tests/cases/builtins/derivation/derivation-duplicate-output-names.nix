(builtins.derivation {
  name = "foo";
  builder = "/bin/sh";
  outputs = ["foo" "foo"];
  system = "x86_64-linux";
}).outPath
