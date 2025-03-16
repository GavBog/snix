# For an explanation of this behavior see //snix/docs/value-pointer-equality.md
let
  g = x:
    owo: "th" + x;
in
[
  (
    { q = g "ia"; } == { q = g ("i" + "a"); }
  )

  (
    [ (g "ia") ] == [ (g ("i" + "a")) ]
  )
]
