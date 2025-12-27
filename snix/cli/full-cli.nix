{ depot, ... }:
depot.snix.cli.default-cli.override {
  pname = "full";
  allFeatures = true;
}
