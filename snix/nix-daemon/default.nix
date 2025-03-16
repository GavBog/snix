{ depot, ... }:

depot.snix.crates.workspaceMembers.nix-daemon.build.override {
  runTests = true;
}
