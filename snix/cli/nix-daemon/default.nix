{ depot, ... }:

depot.snix.crates.workspaceMembers.snix-cli-nix-daemon.build.override {
  runTests = true;
}
