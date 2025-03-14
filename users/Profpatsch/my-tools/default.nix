{ depot, pkgs, lib, ... }:

let
  exes = [ "copy" ];

  drv = pkgs.haskellPackages.mkDerivation {
    pname = "my-tools";
    version = "0.0.1-unreleased";

    src = depot.users.Profpatsch.exactSource ./. [
      ./my-tools.cabal
      ./src/MyTools.hs
      ./exe/Copy.hs
    ];

    isLibrary = false;

    libraryHaskellDepends = [
      depot.users.Profpatsch.my-prelude
      pkgs.haskellPackages.optparse-simple
    ];

    # I copied this from `__generateOptparseApplicativeCompletion` because I can’t be bothered
    # to figure out how the haskellPackages override callPackage bs really works.
    postInstall = lib.concatMapStringsSep "\n"
      (exeName: ''
        bashCompDir="''${!outputBin}/share/bash-completion/completions"
        zshCompDir="''${!outputBin}/share/zsh/vendor-completions"
        fishCompDir="''${!outputBin}/share/fish/vendor_completions.d"
        mkdir -p "$bashCompDir" "$zshCompDir" "$fishCompDir"
        "''${!outputBin}/bin/${exeName}" --bash-completion-script "''${!outputBin}/bin/${exeName}" >"$bashCompDir/${exeName}"
        "''${!outputBin}/bin/${exeName}" --zsh-completion-script "''${!outputBin}/bin/${exeName}" >"$zshCompDir/_${exeName}"
        "''${!outputBin}/bin/${exeName}" --fish-completion-script "''${!outputBin}/bin/${exeName}" >"$fishCompDir/${exeName}.fish"

        # Sanity check
        grep -F ${exeName} <$bashCompDir/${exeName} >/dev/null || {
          echo 'Could not find ${exeName} in completion script.'
          exit 1
        }
      '')
      exes;

    license = lib.licenses.mit;

  };

in
drv
