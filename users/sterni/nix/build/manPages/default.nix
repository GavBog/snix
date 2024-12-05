{ depot, pkgs, lib, ... }:

let
  inherit (pkgs)
    gzip
    mandoc
    coreutils
    ;

  inherit (depot.nix)
    runExecline
    getBins
    ;

  bins = getBins mandoc [ "mandoc" ]
    // getBins gzip [ "gzip" ]
    // getBins coreutils [ "mkdir" "ln" "cp" ]
  ;

  defaultGzip = true;

  basename = gzip: { name, section, ... }:
    "${name}.${toString section}${lib.optionalString gzip ".gz"}";

  manDir = { section, ... }:
    "\${out}/share/man/man${toString section}";

  target = gzip: args:
    "${manDir args}/${basename gzip args}";

  buildManPage =
    { requireLint ? false
    , gzip ? defaultGzip
    , ...
    }:
    { content
    , ...
    }@page:
    let
      source = builtins.toFile (basename false page) content;
    in
    runExecline (basename gzip page) { } ([
      (if requireLint then "if" else "foreground")
      [
        bins.mandoc
        "-mdoc"
        "-T"
        "lint"
        source
      ]
      "importas"
      "out"
      "out"
    ] ++ (if gzip then [
      "redirfd"
      "-w"
      "1"
      "$out"
      bins.gzip
      "-c"
      source
    ] else [
      bins.cp
      "--reflink=auto"
      source
      "$out"
    ]));

  buildManPages =
    name:
    { derivationArgs ? { }
    , gzip ? defaultGzip
    , ...
    }@args:
    pages:
    runExecline "${name}-man-pages"
      {
        inherit derivationArgs;
      }
      ([
        "importas"
        "out"
        "out"
      ] ++ lib.concatMap
        ({ name, section, content }@page: [
          "if"
          [ bins.mkdir "-p" (manDir page) ]
          "if"
          [
            bins.ln
            "-s"
            (buildManPage args page)
            (target gzip page)
          ]
        ])
        pages);

in
{
  __functor = _: buildManPages;

  single = buildManPage;
}
