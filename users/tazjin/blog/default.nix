{ depot, lib, pkgs, ... }:

with depot.nix.yants;

let
  inherit (builtins) hasAttr filter;

  config = {
    name = "tazjin's blog";
    baseUrl = "https://tazj.in/blog";
    staticUrl = "https://tazj.in/static/";

    footer = ''
      <p class="footer">
        <a class="uncoloured-link" href="https://tazj.in">homepage</a>
        |
        <a class="uncoloured-link" href="https://code.tvl.fyi/">code</a>
      </p>
      <p class="lod">ಠ_ಠ</p>
    '';
  };

  inherit (depot.web.blog) post includePost renderPost;

  posts = list post (import ./posts.nix);

  rendered = pkgs.runCommand "tazjins-blog" { } ''
    mkdir -p $out

    ${lib.concatStringsSep "\n" (map (post:
      "cp ${renderPost config post} $out/${post.key}.html"
    ) posts)}
  '';

in
{
  inherit rendered config;

  # Filter unlisted posts from the index
  posts = filter includePost posts;

  # Generate embeddable nginx configuration for redirects from old post URLs
  oldRedirects = lib.concatStringsSep "\n" (map
    (post: ''
      location ~* ^(/en)?/${post.oldKey} {
        return 301 https://tazj.in/blog/${post.key};
      }
    '')
    (filter (hasAttr "oldKey") posts));
}
