use clap::Parser;
use expect_test::expect;
use snix_cli_eval::init_io_handle;
use std::ffi::OsString;
use std::rc::Rc;

macro_rules! test_repl {
    ($name:ident() {$($send:expr => $expect:expr;)*}) => {
        #[test]
        fn $name() {
            let tokio_runtime = tokio::runtime::Runtime::new().unwrap();
            let args = snix_cli_eval::Args::parse_from(vec![
              OsString::from("snix-eval"),
              OsString::from("--extra-nix-path"),
              OsString::from("nixpkgs=/tmp"),
            ]);
            let io_handle = tokio_runtime.block_on(init_io_handle(&args));
            let mut repl = snix_cli_eval::Repl::new(Rc::new(io_handle), &args);
            let mut buffer = std::io::Cursor::new(Vec::new());
            $({
                let result = repl.send(&mut buffer, $send.into());
                $expect.assert_eq(result.output())
                ;
            })*
        }
    }
}

test_repl!(simple_expr_eval() {
    "1" => expect![[r#"
        => 1 :: int
    "#]];
});

test_repl!(multiline_input() {
    "{ x = 1; " => expect![[""]];
    "y = 2; }" => expect![[r#"
        => { x = 1; y = 2; } :: set
    "#]];
});

test_repl!(bind_literal() {
    "x = 1" => expect![[""]];
    "x" => expect![[r#"
        => 1 :: int
    "#]];
});

test_repl!(bind_lazy() {
    "x = { z = 1; }" => expect![[""]];
    "x" => expect![[r#"
        => { z = 1; } :: set
    "#]];
    "x.z" => expect![[r#"
        => 1 :: int
    "#]];
    "x.z" => expect![[r#"
        => 1 :: int
    "#]];
});

test_repl!(bind_lazy_errors() {
    r#"x = (_: "x" + 1)"# => expect![[""]];
    "x null" => expect![[""]];
});

test_repl!(bind_referencing_import() {
    "six = import ./tests/six.nix {}" => expect![[""]];
    "six.six" => expect![[r#"
        => 6 :: int
    "#]];
    "imported = import ./tests/import.nix"  => expect![[""]];
    "(imported {}).six" => expect![[r#"
        => 6 :: int
    "#]];
});

test_repl!(deep_print() {
    "builtins.map (x: x + 1) [ 1 2 3 ]" => expect![[r#"
        => [ <CODE> <CODE> <CODE> ] :: list
    "#]];
    ":p builtins.map (x: x + 1) [ 1 2 3 ]" => expect![[r#"
        => [ 2 3 4 ] :: list
    "#]];
});

test_repl!(explain() {
    ":d { x = 1; y = [ 2 3 4 ]; }" => expect![[r#"
        => a 2-item attribute set
    "#]];
});

test_repl!(reference_nix_path() {
    "<nixpkgs>" => expect![[r#"
        => /tmp :: path
    "#]];
    "<nixpkgs>" => expect![[r#"
        => /tmp :: path
    "#]];
});
