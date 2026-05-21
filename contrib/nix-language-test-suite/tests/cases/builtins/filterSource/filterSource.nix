[
  # complicated_filter_nothing
  (builtins.filterSource (p: t: true) ./import_fixtures)

  # complicated_filter_everything
  (builtins.filterSource (p: t: false) ./import_fixtures)

  # simple_dir_with_one_file_filter_dirs
  (builtins.filterSource (p: t: t != "directory") ./import_fixtures/a_dir)

  # simple dir with one file, filter files
  (builtins.filterSource (p: t: t != "regular") ./import_fixtures/a_dir)

  # simple dir with one file, filter symlinks
  (builtins.filterSource (p: t: t != "symlink") ./import_fixtures/a_dir)

  # simple dir with one file, filter everything
  (builtins.filterSource (p: t: true) ./import_fixtures/a_dir)

  # simple dir with one file, filter nothing
  (builtins.filterSource (p: t: false) ./import_fixtures/a_dir)

  # simple dir with one dir, filter dirs
  (builtins.filterSource (p: t: t != "directory") ./import_fixtures/b_dir)

  # simple dir with one dir, filter files
  (builtins.filterSource (p: t: t != "regular") ./import_fixtures/b_dir)

  # simple dir with one dir, filter symlinks
  (builtins.filterSource (p: t: t != "symlink") ./import_fixtures/b_dir)

  # simple dir with one dir, filter nothing
  (builtins.filterSource (p: t: true) ./import_fixtures/b_dir)

  # simple dir with one dir, filter everything
  (builtins.filterSource (p: t: false) ./import_fixtures/b_dir)

  # simple dir with one symlink to file, filter dirs
  (builtins.filterSource (p: t: t != "directory") ./import_fixtures/c_dir)

  # simple dir with one symlink to file, filter files
  (builtins.filterSource (p: t: t != "regular") ./import_fixtures/c_dir)

  # simple dir with one symlink to file, filter symlinks
  (builtins.filterSource (p: t: t != "symlink") ./import_fixtures/c_dir)

  # simple dir with one symlink to file, filter nothing
  (builtins.filterSource (p: t: true) ./import_fixtures/c_dir)

  # simple dir with one symlink to file, filter everything
  (builtins.filterSource (p: t: false) ./import_fixtures/c_dir)

  # simple dir with dangling symlink, filter dirs
  (builtins.filterSource (p: t: t != "directory") ./import_fixtures/d_dir)

  # simple dir with dangling symlink, filter files
  (builtins.filterSource (p: t: t != "regular") ./import_fixtures/d_dir)

  # simple dir with dangling symlink, filter symlinks
  (builtins.filterSource (p: t: t != "symlink") ./import_fixtures/d_dir)

  # simple dir with dangling symlink, filter everything
  (builtins.filterSource (p: t: true) ./import_fixtures/d_dir)

  # simple dir with dangling symlink, filter nothing
  (builtins.filterSource (p: t: false) ./import_fixtures/d_dir)
]
