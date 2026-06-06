[
  # (fetchTarball "url") cannot be tested, as that one has to fetch from the
  # internet to calculate the path.

  # with url and sha256
  (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/91050ea1e57e50388fa87a3302ba12d188ef723a.tar.gz";
    sha256 = "1hf6cgaci1n186kkkjq106ryf8mmlq9vnwgfwh625wa8hfgdn4dm";
  })

  # with url and sha256 (as SRI)
  (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/91050ea1e57e50388fa87a3302ba12d188ef723a.tar.gz";
    sha256 = "sha256-tRHbnoNI8SIM5O5xuxOmtSLnswEByzmnQcGGyNRjxsE=";
  })

  # with another url, it actually doesn't matter (no .gz prefix)
  (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/91050ea1e57e50388fa87a3302ba12d188ef723a.tar";
    sha256 = "sha256-tRHbnoNI8SIM5O5xuxOmtSLnswEByzmnQcGGyNRjxsE=";
  })

  # … because `name` defaults to source, and that (and the sha256 affect the store path)
  (builtins.fetchTarball {
    name = "source";
    url = "https://github.com/NixOS/nixpkgs/archive/91050ea1e57e50388fa87a3302ba12d188ef723a.tar";
    sha256 = "sha256-tRHbnoNI8SIM5O5xuxOmtSLnswEByzmnQcGGyNRjxsE=";
  })

  # … so changing name causes the hash to change.
  (builtins.fetchTarball {
    name = "some-name";
    url = "https://github.com/NixOS/nixpkgs/archive/91050ea1e57e50388fa87a3302ba12d188ef723a.tar.gz";
    sha256 = "sha256-tRHbnoNI8SIM5O5xuxOmtSLnswEByzmnQcGGyNRjxsE=";
  })
]
