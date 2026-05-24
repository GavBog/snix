{ pkgs, ... }:

# Run a command for each commit since canon and include the files it changes in
# the commit
pkgs.writeShellScriptBin "rebase-exec" ''
  export PATH="${
    pkgs.lib.makeBinPath [
      pkgs.findutils
      pkgs.git
    ]
  }:$PATH"
  REPO_ROOT="''${MG_ROOT:-$(git rev-parse --show-toplevel)}"
  cd "$REPO_ROOT"
  echo "Running:" git rebase --exec "$*" canon
  if ! git rebase --exec "$*" canon ; then
    REBASE_DIR="$(git rev-parse --absolute-git-dir)/rebase-merge"
    REBASE_DIR2="$(git rev-parse --absolute-git-dir)/rebase-apply"
    while [[ -d "$REBASE_DIR" ]] || [[ -d "$REBASE_DIR2" ]] && [[ -n "$(git status --porcelain -uno)" ]]; do
      git add -u
      git commit --amend --no-edit
      git rebase --continue
    done
    if [[ -d "$REBASE_DIR" ]] || [[ -d "$REBASE_DIR2" ]] ; then
      git rebase --abort
    fi
  fi
''
