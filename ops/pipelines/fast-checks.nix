# This file configures the primary build pipeline used for the
# top-level list of depot targets.
{
  depot,
  pkgs,
  externalArgs,
  ...
}:

let
  pipeline = depot.nix.buildkite.mkPipeline {
    headBranch = "refs/heads/canon";
    drvTargets = depot.ci.fastTargets;

    parentTargetMap =
      if (externalArgs ? parentTargetMap) then
        builtins.fromJSON (builtins.readFile externalArgs.parentTargetMap)
      else
        { };
  };

  drvmap = depot.nix.buildkite.mkDrvmap depot.ci.fastTargets;
in
pkgs.runCommand "fast-checks-pipeline" { } ''
  mkdir $out
  if [ -z "$(find "${pipeline}" -maxdepth 0 -type d -empty 2>/dev/null)" ]; then
    cp -r ${pipeline}/* $out
  fi
  cp ${drvmap} $out/drvmap.json
''
