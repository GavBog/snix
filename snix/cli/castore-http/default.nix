{ depot, ... }:

(depot.snix.crates.workspaceMembers.snix-cli-castore-http.build.override {
  runTests = true;
})
