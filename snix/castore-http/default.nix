{ depot, ... }:

(depot.snix.crates.workspaceMembers.snix-castore-http.build.override {
  runTests = true;
})
