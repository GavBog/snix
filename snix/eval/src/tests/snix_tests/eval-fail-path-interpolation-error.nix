# Test that interpolating values that can't be converted to paths fails
let
  number = 4;
in
  /foo/${number}
