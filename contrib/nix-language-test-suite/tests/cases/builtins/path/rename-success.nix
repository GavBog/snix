# Space is an illegal character, but if we specify a name without spaces, it's ok.
[
  (builtins.path {
    name = "valid-name";
    path = ./. + "/te st";
    recursive = false;
  })
  (builtins.path {
    name = "valid-name";
    path = ./. + "/te st";
    recursive = true;
  })
]
