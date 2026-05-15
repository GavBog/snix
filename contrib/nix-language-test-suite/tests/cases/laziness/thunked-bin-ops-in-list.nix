let
  # Necessary to fool the optimiser for && and ||
  true' = true;
  false' = false;
in
[
  (true' && false')
  (true' || false')
  (false -> true)
  (40 + 2)
  (43 - 1)
  (21 * 2)
  (126 / 3)
  ({ } // { bar = null; })
  (12 == 13)
  (3 < 2)
  (4 > 2)
  (23 >= 42)
  (33 <= 22)
  ([ ] ++ [ ])
  (42 != null)
]
