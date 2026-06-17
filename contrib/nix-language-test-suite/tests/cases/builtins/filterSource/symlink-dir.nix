[
  # simple symlinked dir with one file, filter dirs
  (builtins.filterSource (p: t: t != "directory") ./import_fixtures/symlink_to_a_dir)

  # # simple symlinked dir with one file, filter files
  (builtins.filterSource (p: t: t != "regular") ./import_fixtures/symlink_to_a_dir)

  # # simple symlinked dir with one file, filter symlinks
  (builtins.filterSource (p: t: t != "symlink") ./import_fixtures/symlink_to_a_dir)

  # # simple symlinked dir with one file, filter everything
  (builtins.filterSource (p: t: true) ./import_fixtures/symlink_to_a_dir)

  # simple symlinked dir with one file, filter nothing
  (builtins.filterSource (p: t: false) ./import_fixtures/symlink_to_a_dir)
]
