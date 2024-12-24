# html.nix — _the_ most cursed Nix HTML DSL

A quick example to show you what it looks like:

```nix
# Note: this example is for standalone usage out of depot
{ pkgs ? import <nixpkgs> {} }:

let
  # zero dependency, one file implementation
  htmlNix = import ./path/to/html.nix { };

  # make the magic work
  inherit (htmlNix) __findFile esc;
in

pkgs.writeText "example.html" (<html> {} [
  (<head> {} [
    (<meta> { charset = "utf-8"; } null)
    (<title> {} (esc "hello world"))
  ])
  (<body> {} [
    (<h1> {} (esc "hello world"))
    (<p> { class = "intro"; } (esc ''
      welcome to the land of sillyness!
    ''))
    (<ul> {} [
      (<li> {} [
        (esc "check out ")
        (<a> { href = "https://code.tvl.fyi"; } "depot")
      ])
      (<li> {} [
        (esc "find ")
        (<a> { href = "https://cl.tvl.fyi/q/hashtag:cursed"; } "cursed things")
      ])
    ])
  ])
])
```

Convince yourself it works:

```console
$ $BROWSER $(nix-build example.nix)
```

Alternatively, in depot:

```console
$ $BROWSER $(nix-build -A users.sterni.nix.html.tests)
```

## Creating tags

An empty tag is passed `null` as its content argument:

```nix
<link> {
  rel = "stylesheet";
  href = "/main.css";
  type = "text/css";
} null

# => "<link href=\"/main.css\" rel=\"stylesheet\" type=\"text/css\"/>"
```

Content is expected to be HTML:

```nix
<div> { class = "foo"; } "<strong>hi</strong>"

# => "<div class=\"foo\"><strong>hi</strong></div>"
```

If it's not, be sure to escape it:

```nix
<p> {} (esc "A => B")

# => "<p>A =&gt; B</p>"
```

Nesting tags works of course:

```nix
<div> {} (<strong> {} (<em> {} "hi"))

# => "<div><strong><em>hi</em></strong></div>"
```

If the content of a tag is a list, it's concatenated:

```nix
<h1> {} [
  (esc "The ")
  (<strong> {} "Nix")
  (esc " ")
  (<em> {} "Expression")
  (esc " Language")
]

# => "<h1>The <strong>Nix</strong> <em>Expression</em> Language</h1>"
```

More detailed documentation can be found in `nixdoc`-compatible
comments in the source file (`default.nix` in this directory).

## How does this work?

*Theoretically* expressions like `<nixpkgs>` are just ordinary paths —
their actual value is determined from `NIX_PATH`. `html.nix` works
because of how this is actually implemented: At [parse time][spath-parsing]
Nix transparently translates an expression like `<foo>` into
`__findFile __nixPath "foo"`:

```
nix-repl> <nixpkgs>
/nix/var/nix/profiles/per-user/root/channels/vuizvui/nixpkgs

nix-repl> __findFile __nixPath "nixpkgs"
/nix/var/nix/profiles/per-user/root/channels/vuizvui/nixpkgs
```

This translation doesn't take any scoping issues into account --
so we can just shadow `__findFile` and make it return anything,
even a function:

```
nix-repl> __findFile = nixPath: str:
            /**/ if str == "double" then x: x * 2
            else if str == "triple" then x: x * 3
            else throw "what?"

nix-repl> <double> 2
4

nix-repl> <triple> 3
9

nix-repl> <quadruple> 4
error: what?
```

Exactly this is what we are doing in `html.nix`:
Using `let inherit (htmlNix) __findFile; in` we shadow the builtin `__findFile`
with a function which returns a function rendering a particular HTML tag.

[spath-parsing]: https://github.com/NixOS/nix/blob/293220bed5a75efc963e33c183787e87e55e28d9/src/libexpr/parser.y#L410-L416
