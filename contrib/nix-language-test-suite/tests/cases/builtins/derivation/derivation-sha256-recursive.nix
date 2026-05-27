let
  base = {
    name = "foo";
    builder = "/bin/sh";
    system = "x86_64-linux";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };
in [
  # Base case
  (builtins.derivation (base
    // {
      outputHash = "sha256-Q3QXOoy+iN4VK2CflvRulYvPZXYgF0dO7FoF7CvWFTA=";
    })).outPath

  # Base64, same hash
  (builtins.derivation (base
    // {
      outputHash = "Q3QXOoy+iN4VK2CflvRulYvPZXYgF0dO7FoF7CvWFTA=";
    })).outPath

  # Base16, same hash
  (builtins.derivation (base
    // {
      outputHash = "4374173a8cbe88de152b609f96f46e958bcf65762017474eec5a05ec2bd61530";
    })).outPath

  # Base32, same hash
  (builtins.derivation (base
    // {
      outputHash = "0c0msqmyq1asxi74f5r0frjwz2wmdvs9d7v05caxx25yihx1fx23";
    })).outPath

  # Other name, outPath changes
  (builtins.derivation (base
    // {
      name = "foo2";
      outputHash = "sha256-Q3QXOoy+iN4VK2CflvRulYvPZXYgF0dO7FoF7CvWFTA=";
    })).outPath

  # SRI, different hash, outPath changes
  (builtins.derivation (base
    // {
      outputHash = "sha256-fgIr3TyFGDAXP5+qoAaiMKDg/a1MlT6Fv/S/DaA24S8=";
    })).outPath

  # SRI Nopad
  (builtins.derivation (base
    // {
      outputHash = "sha256-fgIr3TyFGDAXP5+qoAaiMKDg/a1MlT6Fv/S/DaA24S8";
    })).outPath
]
