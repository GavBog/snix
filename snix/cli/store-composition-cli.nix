{ depot, ... }:
depot.snix.cli.default-cli.override {
  pname = "store-composition";
  features = [ "xp-store-composition-cli" ];
}
