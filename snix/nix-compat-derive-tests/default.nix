{ depot, ... }:

depot.snix.crates.workspaceMembers.nix-compat-derive-tests.build.override {
  runTests = true;
}
