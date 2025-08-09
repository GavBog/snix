# Check protobuf breaking. Lints already happen in individual targets.
#
{
  depot,
  pkgs,
  lib,
  ...
}:

let
  inherit (depot.nix) bufCheck; # self reference

  script = pkgs.writeShellScriptBin "ci-buf-check" ''
    export PATH="$PATH:${pkgs.lib.makeBinPath [ pkgs.buf ]}"
    # Report-only
    (cd $(git rev-parse --show-toplevel) && (buf breaking . --against "./.git#ref=HEAD~1" || true))
  '';
in

script.overrideAttrs (old: {
  meta = lib.recursiveUpdate old.meta {
    # Protobuf check step executed in the buildkite pipeline which
    # validates that changes to .proto files between revisions
    # don't cause backwards-incompatible or otherwise flawed changes.
    ci.extraSteps.protoCheck = {
      alwaysRun = true;
      label = ":water_buffalo: protoCheck";
      command = pkgs.writeShellScript "ci-buf-check-step" "exec ${depot.nix.bufCheck}/bin/ci-buf-check";
    };
  };
})
