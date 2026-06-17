let
  remove-attr = {
    foo = 1;
    bar = 2;
  };

  attrs = {
    foo = 1;
    bar = 2;
  };
  pos = builtins.unsafeGetAttrPos "foo" (builtins.removeAttrs attrs ["bar"]);
in [
  # Dropping attrs preserves positions of the remaining attrs
  (builtins.unsafeGetAttrPos "foo" (builtins.removeAttrs remove-attr ["bar"]))

  {inherit (pos) column line file;}
]
