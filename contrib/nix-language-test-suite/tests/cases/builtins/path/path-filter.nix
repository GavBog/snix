[
  (builtins.path {
    name = "valid-path";
    path = ./. + "/te st dir";
    filter = _: _: true;
  })
  (builtins.path {
    name = "valid-path";
    path = ./. + "/te st dir";
    filter = _: _: false;
  })
]
