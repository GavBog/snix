{ depot, ... }:
depot.snix.cli.default-cli.override {
  pname = "minimal";
  usesDefaultFeatures = false;
}
