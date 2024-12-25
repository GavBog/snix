# SPDX-License-Identifier: GPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2022-2024 by sterni
{ depot, pkgs, ... }:

(depot.nix.buildLisp.program {
  name = "mblog";

  srcs = [
    ./packages.lisp
    ./config.lisp
    ./maildir.lisp
    ./mail-note/html-transformer.lisp
    ./mail-note/note.lisp
    ./mblog.lisp
    ./cli.lisp
  ];

  deps = [
    {
      sbcl = depot.nix.buildLisp.bundled "uiop";
      default = depot.nix.buildLisp.bundled "asdf";
    }
    depot.lisp.klatre
    depot.third_party.lisp.alexandria
    depot.third_party.lisp.closure-html
    depot.third_party.lisp.cl-date-time-parser
    depot.third_party.lisp.cl-who
    depot.third_party.lisp.local-time
    depot.third_party.lisp.mime4cl
  ];

  main = "cli:main";

  brokenOn = [
    "ecl" # closure-common fails to start up
  ];
}).overrideAttrs (super: {
  # The built binary dispatches based on argv[0]. Building two executables would
  # waste a lot of space.
  buildCommand = ''
    ${super.buildCommand}

    ln -s "$out/bin/mblog" "$out/bin/mnote-html"
  '';
})
