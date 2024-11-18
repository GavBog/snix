{ depot, pkgs, ... }:

let
  inherit (depot.nix) buildBazelPackageNG;
  inherit (buildBazelPackageNG) bazelRulesJavaHook bazelRulesNodeJS5Hook;
in
pkgs.lib.makeOverridable depot.nix.buildBazelPackageNG rec {
  pname = "gerrit";
  version = "3.10.0";

  bazel = pkgs.bazel_7;

  src = (pkgs.fetchgit {
    url = "https://gerrit.googlesource.com/gerrit";
    rev = "v${version}";
    fetchSubmodules = true;
    deepClone = true;
    hash = "sha256-FpKuzityHuHNYBIOL8YUjCLlkuVBfxjvHECb26NsZNE=";
  }).overrideAttrs (_: {
    env.NIX_PREFETCH_GIT_CHECKOUT_HOOK = ''
      pushd "$dir" >/dev/null
      ${pkgs.python3}/bin/python tools/workspace_status_release.py | sort > .version
      popd >/dev/null

      # delete all the .git; we can't do this using fetchgit if deepClone is on,
      # but our mischief has already been achieved by the python command above :)
      find "$dir" -name .git -print0 | xargs -0 rm -rf
    '';
  });
  depsHash = "sha256:114k8ck7056c415qncqmykwqrgprmxnaw3pdv50758mrgw7zdkpm";

  patches = [
    ./0001-Syntax-highlight-nix.patch
    ./0002-Syntax-highlight-rules.pl.patch
    ./0003-Add-titles-to-CLs-over-HTTP.patch
  ];

  nativeBuildInputs = with pkgs; [
    bazelRulesJavaHook
    bazelRulesNodeJS5Hook

    curl
    jdk
    python3
    unzip
  ];

  prePatch = ''
    rm .bazelversion

    ln -sf ${./bazelrc} user.bazelrc

    ln -sf ${./workspace_overrides.bzl} workspace_overrides.bzl
    substituteInPlace WORKSPACE \
      --replace-fail 'load("@io_bazel_rules_webtesting//web:repositories.bzl"' 'load("//:workspace_overrides.bzl"' \
      --replace-fail 'load("@io_bazel_rules_webtesting//web/versioned:browsers-0.3.3.bzl"' 'load("//:workspace_overrides.bzl"'

    patchShebangs Documentation/replace_macros.py
  '';

  postPatch = ''
    sed -Ei 's,^(STABLE_BUILD_GERRIT_LABEL.*)$,\1-dirty-nix,' .version
  '';

  preBuild = ''
    export GERRIT_CACHE_HOME=$HOME/gerrit-cache
  '';

  extraCacheInstall = ''
    cp -R $GERRIT_CACHE_HOME $out/gerrit-cache
  '';

  extraBuildSetup = ''
    ln -sf $cache/gerrit-cache $GERRIT_CACHE_HOME
  '';
  extraBuildInstall = ''
    mkdir -p "$out"/share/api/
    unzip bazel-bin/api-skip-javadoc.zip -d "$out"/share/api
  '';

  bazelTargets = {
    "//:release" = "$out/webapps/gerrit-${version}.war";
    "//:api-skip-javadoc" = null;
  };

  passthru = {
    # A list of plugins that are part of the gerrit.war file.
    # Use `java -jar gerrit.war ls | grep -Po '(?<=plugins/)[^.]+' | sed -e 's,^,",' -e 's,$,",' | sort` to generate that list.
    plugins = [
      "codemirror-editor"
      "commit-message-length-validator"
      "delete-project"
      "download-commands"
      "gitiles"
      "hooks"
      "plugin-manager"
      "replication"
      "reviewnotes"
      "singleusergroup"
      "webhooks"
    ];
  };

  meta.ci.targets = [ "cache" ];
}
