{ depot, pkgs, ... }:

let
  regenerate = pkgs.writeShellScript "regenerate" ''
    (cd $(git rev-parse --show-toplevel)/tvix/store-go && rm *.pb.go && cp ${depot.tvix.store.protos.go-bindings}/*.pb.go . && chmod +w *.pb.go)
  '';
in
(pkgs.buildGoModule {
  name = "store-go";
  src = depot.third_party.gitignoreSource ./.;
  vendorHash = "sha256:1zj42lwx33fwl1kng3zr4mgsnyhik2s728cm9c57qplbrhigpvdz";
}).overrideAttrs (_: {
  meta.ci.extraSteps = {
    check = {
      label = ":water_buffalo: ensure generated protobuf files match";
      needsOutput = true;
      command = pkgs.writeShellScript "pb-go-check" ''
        ${regenerate}
        if [[ -n "$(git status --porcelain -unormal)" ]]; then
            echo "-----------------------------"
            echo ".pb.go files need to be updated, mg run //tvix/store-go/regenerate"
            echo "-----------------------------"
            git status -unormal
            exit 1
        fi
      '';
      alwaysRun = true;
    };
  };
  passthru.regenerate = regenerate;
})
