[
  (builtins.path {
    name = "valid-name";
    path = ./. + "/te st";
    recursive = false;
    sha256 = "sha256-47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=";
  })
  (builtins.path {
    name = "valid-name";
    path = ./. + "/te st";
    recursive = true;
    sha256 = "sha256-d6xi4mKdjkX2JFicDIv5niSzpyI0m/Hnm8GGAIU04kY=";
  })
]
