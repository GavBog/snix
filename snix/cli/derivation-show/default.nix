{ depot, lib, ... }:

depot.snix.crates.workspaceMembers.snix-cli-derivation-show.build.override {
  runTests = true;
}
