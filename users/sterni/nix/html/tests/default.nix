{ depot, pkgs, ... }:

let
  inherit (depot.users.sterni.nix.html)
    __findFile
    esc
    withDoctype
    ;

  exampleDocument = withDoctype (<html> { lang = "en"; } [
    (<head> { } [
      (<meta> { charset = "utf-8"; } null)
      (<title> { } "html.nix example document")
      (<link>
        {
          rel = "license";
          href = "https://code.tvl.fyi/about/LICENSE";
          type = "text/html";
        }
        null)
      (<style> { } (esc ''
        hgroup h2 {
          font-weight: normal;
        }

        dd {
          margin: 0;
        }
      ''))
    ])
    (<body> { } [
      (<main> { } [
        (<hgroup> { } [
          (<h1> { } (esc "html.nix"))
          (<h2> { } [
            (<em> { } "the")
            # test flattening
            [
              (esc " ")
              (esc "most")
              [ (esc " cursed ") ]
              (esc "HTML DSL ever!")
            ]
          ])
        ])
        (<dl> { } [
          (<dt> { } [
            (esc "Q: Wait, it's all ")
            (<a>
              {
                href = "https://cl.tvl.fyi/q/hashtag:cursed";
              }
              (esc "cursed"))
            (esc " nix hacks?")
          ])
          (<dd> { } (esc "A: Always has been. 🔫"))
          (<dt> { } (esc "Q: Why does this work?"))
          (<dd> { } [
            (esc "Because nix ")
            (<a>
              {
                href = "https://github.com/NixOS/nix/blob/293220bed5a75efc963e33c183787e87e55e28d9/src/libexpr/parser.y#L410-L416";
              }
              (esc "translates "))
            (<a>
              {
                href = "https://github.com/NixOS/nix/blob/293220bed5a75efc963e33c183787e87e55e28d9/src/libexpr/lexer.l#L100";
              }
              (esc "SPATH tokens"))
            (esc " like ")
            (<code> { } (esc "<nixpkgs>"))
            (esc " into calls to ")
            (<code> { } (esc "__findFile"))
            (esc " in the ")
            (<em> { } (esc "current"))
            (esc " scope.")
          ])
        ])
      ])
    ])
  ]);
in

pkgs.runCommand "html.nix.html"
{
  passAsFile = [ "exampleDocument" ];
  inherit exampleDocument;
  nativeBuildInputs = [ pkgs.html5validator ];
} ''
  set -x
  test "${esc "<> && \" \'"}" = "&lt;&gt; &amp;&amp; &quot; &#039;"

  # slow as hell unfortunately
  html5validator "$exampleDocumentPath"

  mv "$exampleDocumentPath" "$out"

  set +x
''
