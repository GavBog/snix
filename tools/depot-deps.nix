# Shell derivation to invoke //nix/lazy-deps with the dependencies
# that should be lazily made available in depot.
{ depot, ... }:

depot.nix.lazy-deps {
  age-keygen.attr = "third_party.nixpkgs.age";
  age.attr = "third_party.nixpkgs.age";
  depotfmt.attr = "tools.depotfmt";
  gerrit.attr = "tools.gerrit-cli";
  mg.attr = "tools.magrathea";
  niv.attr = "third_party.nixpkgs.niv";
  nixfmt.attr = "third_party.nixpkgs.nixfmt";

  tf-buildkite = {
    attr = "ops.buildkite.terraform";
    cmd = "terraform";
  };

  tf-dns = {
    attr = "ops.dns.terraform";
    cmd = "terraform";
  };

  tf-hcloud = {
    attr = "ops.hcloud.terraform";
    cmd = "terraform";
  };

  tf-hetzner-s3 = {
    attr = "ops.hetzner-s3.terraform";
    cmd = "terraform";
  };

  tf-keycloak = {
    attr = "ops.keycloak.terraform";
    cmd = "terraform";
  };
}
