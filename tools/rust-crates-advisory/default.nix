{
  depot,
  pkgs,
  lib,
  ...
}:

let
  our-crates = lib.filter (v: v ? outPath) (builtins.attrValues depot.third_party.rust-crates);

  our-crates-lock-file = pkgs.writeText "our-crates-Cargo.lock" (
    lib.concatMapStrings (crate: ''
      [[package]]
      name = "${crate.crateName}"
      version = "${crate.version}"
      source = "registry+https://github.com/rust-lang/crates.io-index"

    '') our-crates
  );

  lock-file-report = pkgs.writers.writeBash "lock-file-report" ''
    set -u

    if test "$#" -lt 2; then
      echo "Usage: $0 IDENTIFIER LOCKFILE [CHECKLIST [MAINTAINERS]]" >&2
      echo 2>&1
      echo "  IDENTIFIER  Unique string describing the lock file" >&2
      echo "  LOCKFILE    Path to Cargo.lock file" >&2
      echo "  CHECKLIST   Whether to use GHFM checklists in the output (true or false)" >&2
      echo "  MAINTAINERS List of @names to cc in case of advisories" >&2
      exit 100
    fi

    ${pkgs.cargo-audit}/bin/cargo-audit audit --json --no-fetch \
      --db "${depot.third_party.rustsec-advisory-db}" \
      --file "$2" \
    | ${pkgs.jq}/bin/jq --raw-output --join-output \
      --from-file "${./format-audit-result.jq}" \
      --arg maintainers "''${4:-}" \
      --argjson checklist "''${3:-false}" \
      --arg attr "$1"

    exit "''${PIPESTATUS[0]}" # inherit exit code from cargo-audit
  '';

  tree-lock-file-report = pkgs.writers.writeBash "tree-lock-file-report" ''
    set -euo pipefail
    status=0

    root="''${1:-.}"

    # Find prints the found lockfiles as <DEPOT ROOT>\t<LOCKFILE DIR>\t<LOCKFILE PATH>\0
    while IFS=$'\t' read -r -d $'\0' entryPoint dir lockFile; do
      label="$(printf '%s' "$dir" | ${pkgs.gnused}/bin/sed "s|^$entryPoint|/|")"
      "${lock-file-report}" "$label" "$lockFile" || status=1
    done < <(${pkgs.findutils}/bin/find "$root" -type f -name Cargo.lock -printf '%H\t%h\t%p\0' )

    exit $status
  '';

  depot-rust-crates-advisory-report = pkgs.writers.writeBash "depot-advisory-report" ''
    set -eu
    status=0

    "${lock-file-report}" "//third_party/rust-crates" "${our-crates-lock-file}" || status=1
    "${tree-lock-file-report}" || status=1

    exit $status
  '';

  buildkiteReportStep =
    {
      command,
      context ? null,
      style ? "warning",
    }:
    let
      commandName = depot.nix.utils.storePathName (builtins.head command);
    in

    pkgs.writers.writeBash "buildkite-report-${commandName}" ''
      set -uo pipefail

      report="$(${lib.escapeShellArgs command})"

      if test $? -ne 0; then
         printf "%s" "$report" | \
         buildkite-agent annotate ${
           lib.escapeShellArgs (
             [
               "--style"
               style
             ]
             ++ lib.optionals (context != null) [
               "--context"
               context
             ]
           )
         }
      fi
    '';

in
depot.nix.readTree.drvTargets {
  inherit
    lock-file-report
    ;

  tree-lock-file-report = tree-lock-file-report // {
    meta.ci.extraSteps.run = {
      label = "Check all crates used in depot for advisories";
      alwaysRun = true;
      command = buildkiteReportStep {
        command = [ depot-rust-crates-advisory-report ];
        style = "warning";
        context = "depot-crate-advisories";
      };
    };
  };
}
