{ pkgs, ... }:

pkgs.runCommandNoCC "git-only-push"
{
  nativeBuildInputs = [ pkgs.buildPackages.shellcheck ];
  buildInputs = [ pkgs.bash ];
  src = ./git-only-push.sh;
}
  ''
    shellcheck "$src"
    install -Dm755 "$src" "$out/bin/git-only-push"
  ''
