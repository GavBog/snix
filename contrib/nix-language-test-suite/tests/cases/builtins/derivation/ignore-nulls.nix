let
  base = {
    name = "foo";
    system = ":";
    builder = ":";
  };
in [
  # __ignoreNulls = true, but nothing set to null
  (builtins.derivation (base
    // {
      __ignoreNulls = true;
    })).drvPath

  (builtins.derivation (base
    // {
      __ignoreNulls = true;
    })).outPath

  # __ignoreNulls = true, with a null arg, same paths
  (builtins.derivation (base
    // {
      __ignoreNulls = true;
      ignoreme = null;
    })).drvPath

  (builtins.derivation (base
    // {
      __ignoreNulls = true;
      ignoreme = null;
    })).outPath

  # __ignoreNulls = false
  (builtins.derivation (base
    // {
      __ignoreNulls = false;
    })).drvPath

  (builtins.derivation (base
    // {
      __ignoreNulls = false;
    })).outPath

  # __ignoreNulls = false, with a null arg
  (builtins.derivation (base
    // {
      __ignoreNulls = false;
      foo = null;
    })).drvPath

  (builtins.derivation (base
    // {
      __ignoreNulls = false;
      foo = null;
    })).outPath
]
