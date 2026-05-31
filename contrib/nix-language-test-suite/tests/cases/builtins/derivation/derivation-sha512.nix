[
  (builtins.derivation {
    name = "foo";
    builder = "/bin/sh";
    system = "x86_64-linux";
    outputHashMode = "recursive";
    outputHashAlgo = "sha512";
    outputHash = "sha512-DPkYCnZKuoY6Z7bXLwkYvBMcZ3JkLLLc5aNPCnAvlHDdwr8SXBIZixmVwjPDS0r9NGxUojNMNQqUilG26LTmtg==";
  }).outPath

  (builtins.derivation {
    name = "foo";
    builder = "/bin/sh";
    system = "x86_64-linux";
    outputHashMode = "flat";
    outputHashAlgo = "sha512";
    outputHash = "sha512-DPkYCnZKuoY6Z7bXLwkYvBMcZ3JkLLLc5aNPCnAvlHDdwr8SXBIZixmVwjPDS0r9NGxUojNMNQqUilG26LTmtg==";
  }).outPath
]
