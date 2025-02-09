# A rendition of everyone's favourite computer theme.
{ pkgs, ... }:

let
  # Chicago95 has no GTK-4 theme (because GTK-4 removed important features that
  # it needs), but there is a project with an approximation.
  #
  # This is a bit of a hack, but I inject that project's GTK-4 theme as if it
  # was a part of Chicago95.
  #
  # This other project is GPL-3.0, under which Chicago95 is also distributed.
  gtk4ProjectSrc = pkgs.fetchFromGitHub {
    owner = "B00merang-Project";
    repo = "Windows-95";
    rev = "055abd7a3608afdcb2ef021732e07020f2b416b2";
    hash = "sha256:1li6wzyn3y09d188xki1h96pmn4xcx2lklfc4rkiq2y2r22wx7kz";
  };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "Chicago95";
  version = "master";

  src = pkgs.fetchFromGitHub {
    owner = "grassmunk";
    repo = "Chicago95";
    rev = "bdf5cf36a16102aaac297f3de887c601c2b1146f";
    hash = "sha256:11fsy3bam1rhp1292zflvzmf1432z1p0ncwy3601wl2f8rnvfdfm";
  };

  # The project has a Makefile, but it's broken in all sorts of ways, so we just
  # copy the important stuff manually.
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/share/{icons,fonts,themes,sounds,qt5ct/colors}

    cp -r Theme/Chicago95 $out/share/themes
    cp -r Icons/* $out/share/icons
    cp -r Cursors/* $out/share/icons
    cp -r Fonts/* $out/share/fonts
    cp Extras/Chicago95_qt.conf $out/share/qt5ct/colors

    cp -r ${gtk4ProjectSrc}/gtk-4.0 $out/share/themes/Chicago95
  '';

  # TODO(tazjin): investigate various broken symlinks in $out/share/icons
  dontCheckForBrokenSymlinks = true;

  meta.license = pkgs.lib.licenses.gpl3;
}

