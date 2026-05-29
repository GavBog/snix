(builtins.derivation {
  name = "foo";
  system = ":";
  builder = ":";
  foo = "bar";
  # __json must contain a valid JSON string
  # but it does not
  __json = "foo";
}).drvPath
