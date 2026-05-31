[
  # Base success
  (derivation {
    name = "foo";
    builder = "/bin/sh";
    system = "x86_64-linux";
  }).outPath

  # Sha256 with outputHashAlgo omitted
  (builtins.derivation {
    name = "foo";
    builder = "/bin/sh";
    system = "x86_64-linux";
    outputHashMode = "recursive";
    outputHash = "sha256-Q3QXOoy+iN4VK2CflvRulYvPZXYgF0dO7FoF7CvWFTA=";
  }).outPath

  # Sha256 with outputHashAlgo and outputHashMode omitted
  (builtins.derivation {
    name = "foo";
    builder = "/bin/sh";
    system = "x86_64-linux";
    outputHash = "sha256-Q3QXOoy+iN4VK2CflvRulYvPZXYgF0dO7FoF7CvWFTA=";
  }).outPath

  # Multiple outputs
  (builtins.derivation {
    name = "foo";
    builder = "/bin/sh";
    outputs = ["foo" "bar"];
    system = "x86_64-linux";
  }).outPath

  # Multiple args
  (builtins.derivation {
    name = "foo";
    builder = "/bin/sh";
    args = ["--foo" "42" "--bar"];
    system = "x86_64-linux";
  }).outPath

  # PassAsFile
  (builtins.derivation {
    "name" = "foo";
    passAsFile = ["bar"];
    bar = "baz";
    system = ":";
    builder = ":";
  }).outPath
]
