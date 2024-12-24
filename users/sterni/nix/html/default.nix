# SPDX-FileCopyrightText: Copyright © 2021, 2024 sterni
# SPDX-License-Identifier: MIT
#
# This file provides a cursed HTML DSL for nix which works by overloading
# the NIX_PATH lookup operation via angle bracket operations, e. g. `<nixpkgs>`.

{ ... }:

let
  /* Escape everything we have to escape in an HTML document if either
     in a normal context or an attribute string (`<>&"'`).

     A shorthand for this function called `esc` is also provided.

     Type: string -> string

     Example:

     escapeMinimal "<hello>"
     => "&lt;hello&gt;"
  */
  escapeMinimal = builtins.replaceStrings
    [ "<" ">" "&" "\"" "'" ]
    [ "&lt;" "&gt;" "&amp;" "&quot;" "&#039;" ];

  /* Return a string with a correctly rendered tag of the given name,
     with the given attributes which are automatically escaped.

     If the content argument is `null`, the tag will have no children nor a
     closing element. If the content argument is a string it is used as the
     content as is (unescaped). If the content argument is a list, its
     elements are concatenated (recursively if necessary).

     `renderTag` is only an internal function which is reexposed as `__findFile`
     to allow for much neater syntax than calling `renderTag` everywhere:

     ```nix
     { depot, ... }:
     let
       inherit (depot.users.sterni.nix.html) __findFile esc;
     in

     <html> {} [
       (<head> {} (<title> {} (esc "hello world")))
       (<body> {} [
         (<h1> {} (esc "hello world"))
         (<p> {} (esc "foo bar"))
       ])
     ]

     ```

     As you can see, the need to call a function disappears, instead the
     `NIX_PATH` lookup operation via `<foo>` is overloaded, so it becomes
     `renderTag "foo"` automatically.

     Since the content argument may contain the result of other `renderTag`
     calls, we can't escape it automatically. Instead this must be done manually
     using `esc`.

     If the tag is "html", e.g. in case of `<html> { } …`, "<!DOCTYPE html> will
     be prepended to the normal rendering of the text.

     Type: string -> attrs<string> -> (list<string> | string | null) -> string

     Example:

     <link> {
       rel = "stylesheet";
       href = "/css/main.css";
       type = "text/css";
     } null

     renderTag "link" {
       rel = "stylesheet";
       href = "/css/main.css";
       type = "text/css";
     } null

     => "<link href=\"/css/main.css\" rel=\"stylesheet\" type=\"text/css\"/>"

     <p> {} [
       "foo "
       (<strong> {} "bar")
     ]

     renderTag "p" {} "foo <strong>bar</strong>"
     => "<p>foo <strong>bar</strong></p>"
  */
  renderTag = tag: attrs: content:
    let
      attrs' = builtins.concatStringsSep "" (
        builtins.map
          (n:
            " ${escapeMinimal n}=\"${escapeMinimal (toString attrs.${n})}\""
          )
          (builtins.attrNames attrs)
      );
      content' =
        if builtins.isList content
        then builtins.concatStringsSep "" (flatten content)
        else content;
    in
    (if tag == "html" then "<!DOCTYPE html>" else "") +
    (if content == null
    then "<${tag}${attrs'}/>"
    else "<${tag}${attrs'}>${content'}</${tag}>");

  /* Deprecated, does nothing.
  */
  withDoctype = doc: builtins.trace
    "WARN: withDoctype no longer does anything, `<html> { } [ … ]` takes care of rendering <!DOCTYPE html>"
    doc;

  /* Taken from <nixpkgs/lib/lists.nix>. */
  flatten = x:
    if builtins.isList x
    then builtins.concatMap (y: flatten y) x
    else [ x ];

in
{
  inherit escapeMinimal renderTag withDoctype;

  __findFile = _: renderTag;
  esc = escapeMinimal;
}
