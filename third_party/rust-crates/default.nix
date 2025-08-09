{ depot, pkgs, ... }:

# TVL tool rust crate dependencies, where tools like carnix are not used.
# Intended for manual updates, which makes sure we never actually update.

let
  inherit (pkgs) fetchpatch;

  buildRustCrate =
    attrs@{
      edition ? "2018",
      pname,
      crateName ? pname,
      ...
    }:
    pkgs.buildRustCrate (
      attrs
      // {
        inherit
          crateName
          edition
          ;
      }
    );
in
depot.nix.readTree.drvTargets rec {
  cfg-if = buildRustCrate {
    pname = "cfg-if";
    version = "1.0.0";
    sha256 = "1fzidq152hnxhg4lj6r2gv4jpnn8yivp27z6q6xy7w6v0dp6bai9";
  };

  cc = buildRustCrate {
    pname = "cc";
    version = "1.0.66";
    sha256 = "12q71z6ck8wlqrwgi25x3lrryyks9djymswn9b1c6qq0i01jpc1p";
  };

  ascii = buildRustCrate {
    pname = "ascii";
    version = "1.0.0";
    edition = "2015";
    sha256 = "0gam8xsn981wfa40srsniivffjsfz1pg0xnigmczk9k7azb1ks1m";
  };

  regex-syntax = buildRustCrate {
    pname = "regex-syntax";
    version = "0.6.25";
    edition = "2015";
    sha256 = "0i211p26m97ii169g0f4gf2a99r8an4xc1fdqj0sf5wpn17qhs29";
  };

  regex = buildRustCrate {
    pname = "regex";
    version = "1.5.5";
    features = [ "std" ];
    dependencies = [ regex-syntax ];
    edition = "2018";
    sha256 = "0i7yrxsvxpx682vdbkvj7j4w3a3z2c1qwmaa795mm9a9prx4yzjk";
  };

  libloading = buildRustCrate {
    pname = "libloading";
    version = "0.6.7";
    dependencies = [ cfg-if ];
    edition = "2015";
    sha256 = "111d8zsizswnxiqn43vcgnc2ym9spsx1i6pcfp35ca3yw2ixq95j";
  };

  tree-sitter = buildRustCrate {
    pname = "tree-sitter";
    # buildRustCrate isn’t really smart enough to detect the subdir
    libPath = "binding_rust/lib.rs";
    # and the build.rs is also not where buildRustCrate would find it
    build = "binding_rust/build.rs";
    version = "0.17.1";
    dependencies = [ regex ];
    buildDependencies = [ cc ];
    sha256 = "0jwwbvs4icpra7m1ycvnyri5h3sbw4qrfvgnnvnk72h4w93qhzhr";
  };

  libc = buildRustCrate {
    pname = "libc";
    version = "0.2.153";
    edition = "2015";
    sha256 = "1xz1nz9k0vrv7lbir7ma0q4ii9cp3c0s9fbxp6268film2wrxs19";
  };

  bitflags = buildRustCrate {
    pname = "bitflags";
    version = "2.4.2";
    sha256 = "1p370m8qh3clk33rqmyglcphlsq0gpf69j22d61fy4kkmrfn8hbd";
  };

  inotify-sys = buildRustCrate {
    pname = "inotify-sys";
    version = "0.1.5";
    dependencies = [ libc ];
    sha256 = "1yiy577xxhi0j90nbg9nkd8cqwc1xix62rz55jjngvxa5jl5613v";
  };

  inotify = buildRustCrate {
    pname = "inotify";
    version = "0.10.2";
    patches = [
      # Unreleased compat patch for bitflags >= 2
      (fetchpatch {
        name = "inotify-bitflags-2.patch";
        url = "https://github.com/hannobraun/inotify-rs/commit/f4765593894ef0b36d39739cf3349485ca88b1ce.patch";
        sha256 = "107r9jai0jdr0hybsvbjyjn23vyk2lp1l1pmznb7jp38my0grh4b";
        excludes = [ "Cargo.toml" ];
      })
    ];
    dependencies = [
      bitflags
      libc
      inotify-sys
    ];
    sha256 = "0lqwk7yf6bzc2jzj5iji2p3f29zdpllqd207vgg7jswmg2gqnlqc";
  };

  httparse = buildRustCrate {
    pname = "httparse";
    version = "1.3.4";
    edition = "2015";
    sha256 = "0dggj4s0cq69bn63q9nqzzay5acmwl33nrbhjjsh5xys8sk2x4jw";
  };

  version-check = buildRustCrate {
    pname = "version_check";
    version = "0.9.2";
    edition = "2015";
    sha256 = "1vwvc1mzwv8ana9jv8z933p2xzgj1533qwwl5zr8mi89azyhq21v";
  };

  memchr = buildRustCrate {
    pname = "memchr";
    version = "2.3.3";
    edition = "2015";
    sha256 = "1ivxvlswglk6wd46gadkbbsknr94gwryk6y21v64ja7x4icrpihw";
  };
  nom = buildRustCrate {
    pname = "nom";
    version = "5.1.1";
    sha256 = "1gb4r6mjwd645jqh02nhn60i7qkw8cgy3xq1r4clnmvz3cmkv1l0";
    dependencies = [ memchr ];
    buildDependencies = [ version-check ];
    features = [
      "std"
      "alloc"
    ];
  };

  base64 = buildRustCrate {
    pname = "base64";
    version = "0.13.0";
    sha256 = "0i0jk5sgq37kc4c90d1g7dp7zvphbg0dbqc1ajnn0vffjxblgamg";
    features = [
      "alloc"
      "std"
    ];
  };

  bufstream = buildRustCrate {
    pname = "bufstream";
    version = "0.1.4";
    sha256 = "10rqm7jly5jjx7wcc19q6q4m2zsrw3l2v3m1054wnbwvdh42xxf1";
  };

  autocfg = buildRustCrate {
    pname = "autocfg";
    version = "1.0.1";
    edition = "2015";
    sha256 = "1lsjz23jdcchcqbsmlzd4iksg3hc8bdvy677jy0938i2gp24frw1";
  };

  num-traits = buildRustCrate {
    pname = "num-traits";
    version = "0.2.14";
    edition = "2015";
    buildDependencies = [ autocfg ];
    sha256 = "09ac9dcp6cr57vjzyiy213y7312jqcy84mkamp99zr40qd1gwnyk";
  };

  num-integer = buildRustCrate {
    pname = "num-integer";
    version = "0.1.44";
    edition = "2015";
    dependencies = [ num-traits ];
    buildDependencies = [ autocfg ];
    sha256 = "1gdbnfgnivp90h644wmqj4a20yfmdga2xxxacx53pjbcazvfvajc";
  };

  chrono = buildRustCrate {
    pname = "chrono";
    version = "0.4.22";
    edition = "2018";
    dependencies = [
      num-traits
      num-integer
    ];
    features = [
      "alloc"
      "std"
    ];
    sha256 = "01vbn93ba1q2afq10qis41j847damk5ifgn1all337mcscl345fn";
  };

  imap-proto = buildRustCrate {
    pname = "imap-proto";
    version = "0.10.2";
    dependencies = [ nom ];
    sha256 = "1bf5r4d0z7c8wxrvr7kjy26500wr7cd4sxz49ix3b3yzc6ayyqv1";
  };

  lazy_static = buildRustCrate {
    pname = "lazy_static";
    version = "1.4.0";
    sha256 = "13h6sdghdcy7vcqsm2gasfw3qg7ssa0fl3sw7lq6pdkbk52wbyfr";
  };

  imap = buildRustCrate {
    pname = "imap";
    version = "2.4.0";
    dependencies = [
      base64
      bufstream
      chrono
      imap-proto
      lazy_static
      nom
      regex
    ];
    sha256 = "1nj6x45qnid98nv637623rrh7imcxk0kad89ry8j5dkkgccvjyc0";
  };

  epoll = buildRustCrate {
    pname = "epoll";
    version = "4.3.3";
    dependencies = [
      bitflags
      libc
    ];
    sha256 = "1wc8dsd0dhqgskmkwd82fzqsy2hg0wm3833jxhzxkrwcip25yr3a";
  };

  serde = buildRustCrate {
    pname = "serde";
    version = "1.0.123";
    edition = "2015";
    sha256 = "05xl2s1vpf3p7fi2yc9qlzw88d5ap0z3qmhmd7axa6pp9pn1s5xc";
    features = [ "std" ];
  };

  ryu = buildRustCrate {
    pname = "ryu";
    version = "1.0.5";
    sha256 = "060y2ln1csix593ingwxr2y3wl236ls0ly1ffkv39h5im7xydhrc";
  };

  itoa = buildRustCrate {
    pname = "itoa";
    version = "0.4.7";
    sha256 = "0079jlkcmcaw37wljrvb6r3dqq15nfahkqnl5npvlpdvkg31k11x";
  };

  serde_json = buildRustCrate {
    pname = "serde_json";
    version = "1.0.62";
    sha256 = "0sgc8dycigq0nxr4j613m4q733alfb2i10s6nz80lsbbqgrka21q";
    dependencies = [
      serde
      ryu
      itoa
    ];
    features = [ "std" ];
  };

  log = buildRustCrate {
    pname = "log";
    version = "0.4.11";
    sha256 = "0m6xhqxsps5mgd7r91g5mqkndbh8zbjd58p7w75r330zl4n40l07";
    dependencies = [ cfg-if ];
  };

  mustache = buildRustCrate {
    pname = "mustache";
    version = "0.9.0";
    edition = "2015";
    sha256 = "1zgl8l15i19lzp90icgwyi6zqdd31b9vm8w129f41d1zd0hs7ayq";
    dependencies = [
      log
      serde
    ];
  };

  semver-parser = buildRustCrate {
    pname = "semver-parser";
    version = "0.7.0";
    edition = "2015";
    sha256 = "1da66c8413yakx0y15k8c055yna5lyb6fr0fw9318kdwkrk5k12h";
  };

  semver = buildRustCrate {
    pname = "semver";
    version = "0.10.0";
    edition = "2015";
    sha256 = "0pbkdwlpq4d0hgdrymm2rcw31plni2siwd882gbcbscjvyvrrrqa";
    dependencies = [ semver-parser ];
  };

  toml = buildRustCrate {
    pname = "toml";
    version = "0.5.8";
    sha256 = "1vwjwmwsy83pbgvvm11a6grbhb09zkcrv9v95wfwv48wjm01wdj4";
    edition = "2018";
    dependencies = [ serde ];
  };

  pkg-config = buildRustCrate {
    pname = "pkg-config";
    version = "0.3.19";
    sha256 = "1kd047p8jv6mhmfzddjvfa2nwkfrb3l1wml6lfm51n1cr06cc9lz";
  };

}
