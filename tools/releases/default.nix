# Definitions for simple release mechanisms from depot.
{
  depot,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.strings) makeBinPath sanitizeDerivationName;
in
{
  # Use a josh filter to push a certain subset of canon to another git
  # repository.
  #
  # This expects, of course, that the remote repository has granted
  # push access to the CI SSH key.
  filteredGitPush =
    {
      filter,
      remote,
      ref ? "refs/heads/canon",
    }:
    {
      label = ":git: push '${filter}' to external git repository";
      branches = [ "refs/heads/canon" ];
      phase = "release";

      command = pkgs.writeShellScript "${sanitizeDerivationName filter}-push" ''
        set -e
        export PATH="${
          makeBinPath [
            pkgs.git
            pkgs.josh
          ]
        }:$PATH"

        echo 'Filtering depot through ${filter}'
        josh-filter '${filter}'

        echo 'Fetching remote to check if a push is needed'
        git fetch '${remote}' '${ref}'

        if git merge-base --is-ancestor FILTERED_HEAD FETCH_HEAD; then
          echo 'Commit already present, nothing to push.'
          exit 0
        fi

        echo 'Pushing filtered repository to ${remote}:${ref}'
        git push '${remote}' 'FILTERED_HEAD:${ref}'
      '';
    };
}
