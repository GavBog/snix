# For an explanation of this behavior see //snix/docs/value-pointer-equality.md
let
  f = owo: "thia";
in

[ f 42 ] > [ f 21 ]
