# The case is based on https://github.com/NixOS/nix/blob/915772aa5ee56f639730cf616218aab5f8f68e07/src/libexpr-tests/primops.cc#L291-L303
builtins.functionArgs ({ x, y ? 123}: 1)
