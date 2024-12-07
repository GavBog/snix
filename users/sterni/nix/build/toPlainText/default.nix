{ pkgs, depot, lib, ... }:

{ fmt ? null
, passthru ? { }
, ...
}@args:

let
  inherit (depot.nix) getBins utils;

  bins = getBins pkgs.lowdown [
    "lowdown"
  ] // getBins pkgs.mandoc [
    "mandoc"
  ] // getBins pkgs.gnused [
    "sed"
  ];

  actions = {
    mdoc = ''
      ${bins.mandoc} -T utf8 "${thing}" > "$out"
    '';

    # Use lowdown's terminal target, but strip all ANSI SGR escape sequences
    markdown = ''
      ${bins.lowdown} -Tterm "${thing}" \
      | ${bins.sed} -e 's|\\x1b\\[[;0-9]*m||g' \
      > "$out"
    '';

    plain = ''
      cp --reflink=auto "${thing}" "$out"
    '';
  };

  thingType = builtins.head (
    builtins.filter (x: x != null) (
      builtins.map (t: if args ? ${t} then t else null) (
        builtins.attrNames actions
      )
    )
  );

  thing = args.${thingType};
  name = args.name or utils.storePathName thing;
in

pkgs.runCommand name
{
  inherit passthru;
}
  (
    actions.${thingType} + lib.optionalString (fmt != null) ''
      fmt -w "${lib.escapeShellArg (toString fmt)}" "$out"
    ''
  )
