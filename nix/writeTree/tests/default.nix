{
  depot,
  pkgs,
  lib,
  ...
}:

let
  inherit (pkgs) runCommand writeText writeTextFile;
  inherit (depot.nix) writeTree;

  checkTree =
    name: tree: expected:
    runCommand "writeTree-test-${name}"
      {
        nativeBuildInputs = [ pkgs.buildPackages.lr ];
        passAsFile = [ "expected" ];
        inherit expected;
      }
      ''
        actualPath="$NIX_BUILD_TOP/actual"
        cd ${lib.escapeShellArg (writeTree name tree)}
        lr . > "$actualPath"
        diff -u "$expectedPath" "$actualPath" | tee "$out"
      '';
in

depot.nix.readTree.drvTargets {
  empty = checkTree "empty" { } ''
    .
  '';

  simple-paths =
    checkTree "simple"
      {
        writeTree = {
          meta = {
            "owners.txt" = ../OWNERS;
          };
          "code.nix" = ../default.nix;
          all-tests = ./.;
          nested.dirs.eval-time = builtins.toFile "owothia" ''
            hold me owo
          '';
        };
      }
      ''
        .
        ./writeTree
        ./writeTree/all-tests
        ./writeTree/all-tests/default.nix
        ./writeTree/code.nix
        ./writeTree/meta
        ./writeTree/meta/owners.txt
        ./writeTree/nested
        ./writeTree/nested/dirs
        ./writeTree/nested/dirs/eval-time
      '';

  empty-dirs =
    checkTree "empty-dirs"
      {
        this.dir.is.empty = { };
        so.is.this.one = { };
      }
      ''
        .
        ./so
        ./so/is
        ./so/is/this
        ./so/is/this/one
        ./this
        ./this/dir
        ./this/dir/is
        ./this/dir/is/empty
      '';

  drvs =
    checkTree "drvs"
      {
        file-drv = writeText "road.txt" ''
          Any road followed precisely to its end leads precisely nowhere.
        '';
        dir-drv = writeTextFile {
          name = "dir-of-text";
          destination = "/text/in/more/dirs.txt";
          text = ''
            Climb the mountain just a little bit to test that it’s a mountain.
            From the top of the mountain, you cannot see the mountain.
          '';
        };
      }
      ''
        .
        ./dir-drv
        ./dir-drv/text
        ./dir-drv/text/in
        ./dir-drv/text/in/more
        ./dir-drv/text/in/more/dirs.txt
        ./file-drv
      '';
}
