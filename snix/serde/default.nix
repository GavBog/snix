{ depot, ... }:

depot.snix.crates.workspaceMembers.snix-serde.build.override {
  runTests = true;
}
