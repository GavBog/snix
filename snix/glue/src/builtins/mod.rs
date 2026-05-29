//! Contains builtins that deal with the store or builder.

use std::rc::Rc;

use crate::snix_store_io::SnixStoreIO;

mod derivation;
mod errors;
mod fetchers;
mod import;
mod utils;

pub use errors::{DerivationError, FetcherError, ImportError};

/// Adds derivation-related builtins to the passed [snix_eval::EvaluationBuilder]:
///
/// * `derivation`
/// * `derivationStrict`
/// * `toFile`
///
/// As they need to interact with `known_paths`, we also need to pass in
/// `known_paths`.
pub fn add_derivation_builtins<'co, 'ro, 'env, IO>(
    eval_builder: snix_eval::EvaluationBuilder<'co, 'ro, 'env, IO>,
    io: Rc<SnixStoreIO>,
) -> snix_eval::EvaluationBuilder<'co, 'ro, 'env, IO> {
    eval_builder
        .add_builtins(derivation::derivation_builtins::builtins(Rc::clone(&io)))
        // Add the actual `builtins.derivation` from compiled Nix code
        .add_src_builtin("derivation", include_str!("derivation.nix"))
}

/// Adds fetcher builtins to the passed [snix_eval::EvaluationBuilder]:
///
/// * `fetchurl`
/// * `fetchTarball`
/// * `fetchGit`
pub fn add_fetcher_builtins<'co, 'ro, 'env, IO>(
    eval_builder: snix_eval::EvaluationBuilder<'co, 'ro, 'env, IO>,
    io: Rc<SnixStoreIO>,
) -> snix_eval::EvaluationBuilder<'co, 'ro, 'env, IO> {
    eval_builder.add_builtins(fetchers::fetcher_builtins::builtins(Rc::clone(&io)))
}

/// Adds import-related builtins to the passed [snix_eval::EvaluationBuilder]:
///
///
/// * `filterSource`
/// * `path`
/// * `storePath`
///
/// As they need to interact with the store implementation, we pass [`SnixStoreIO`].
/// Due to #176, some IO still sidesteps `EvalIO` and accesses the filesystem directly.
pub fn add_import_builtins<'co, 'ro, 'env, IO>(
    eval_builder: snix_eval::EvaluationBuilder<'co, 'ro, 'env, IO>,
    io: Rc<SnixStoreIO>,
) -> snix_eval::EvaluationBuilder<'co, 'ro, 'env, IO> {
    eval_builder.add_builtins(import::import_builtins(io))
}

#[cfg(test)]
mod tests {
    use std::{rc::Rc, sync::Arc};

    use crate::snix_store_io::SnixStoreIO;

    use super::{add_derivation_builtins, add_fetcher_builtins, add_import_builtins};
    use clap::Parser;
    use nix_compat::store_path::hash_placeholder;
    use rstest::rstest;
    use snix_build::buildservice::DummyBuildService;
    use snix_eval::{EvalIO, EvaluationResult};
    use snix_store::utils::{ServiceUrlsMemory, construct_services};

    /// evaluates a given nix expression and returns the result.
    /// Takes care of setting up the evaluator so it knows about the
    // `derivation` builtin.
    fn eval(str: &str) -> EvaluationResult {
        // We assemble a complete store in memory.
        let runtime = tokio::runtime::Runtime::new().expect("Failed to build a Tokio runtime");
        let (blob_service, directory_service, path_info_service, nar_calculation_service) = runtime
            .block_on(async {
                construct_services(ServiceUrlsMemory::parse_from(std::iter::empty::<&str>())).await
            })
            .expect("Failed to construct store services in memory");

        let io = Rc::new(SnixStoreIO::new(
            blob_service,
            directory_service,
            path_info_service,
            nar_calculation_service.into(),
            Arc::<DummyBuildService>::default(),
            runtime.handle().clone(),
            Vec::new(),
        ));

        let mut eval_builder = snix_eval::Evaluation::builder(io.clone() as Rc<dyn EvalIO>);
        eval_builder = add_derivation_builtins(eval_builder, Rc::clone(&io));
        eval_builder = add_fetcher_builtins(eval_builder, Rc::clone(&io));
        eval_builder = add_import_builtins(eval_builder, io);
        let eval = eval_builder.build();

        // run the evaluation itself.
        eval.evaluate(str, None)
    }

    /// construct some calls to builtins.derivation and compare produced output
    /// paths.
    #[rstest]
    #[case::r_sha1(r#"(builtins.derivation { name = "foo"; builder = "/bin/sh"; system = "x86_64-linux"; outputHashMode = "recursive"; outputHashAlgo = "sha1"; outputHash = "sha1-VUCRC+16gU5lcrLYHlPSUyx0Y/Q="; }).outPath"#, "/nix/store/p5sammmhpa84ama7ymkbgwwzrilva24x-foo")]
    #[case::r_md5(r#"(builtins.derivation { name = "foo"; builder = "/bin/sh"; system = "x86_64-linux"; outputHashMode = "recursive"; outputHashAlgo = "md5"; outputHash = "md5-07BzhNET7exJ6qYjitX/AA=="; }).outPath"#, "/nix/store/gmmxgpy1jrzs86r5y05wy6wiy2m15xgi-foo")]
    #[case::r_sha512(r#"(builtins.derivation { name = "foo"; builder = "/bin/sh"; system = "x86_64-linux"; outputHashMode = "recursive"; outputHashAlgo = "sha512"; outputHash = "sha512-DPkYCnZKuoY6Z7bXLwkYvBMcZ3JkLLLc5aNPCnAvlHDdwr8SXBIZixmVwjPDS0r9NGxUojNMNQqUilG26LTmtg=="; }).outPath"#, "/nix/store/lfi2bfyyap88y45mfdwi4j99gkaxaj19-foo")]
    #[case::sha1(r#"(builtins.derivation { name = "foo"; builder = "/bin/sh"; system = "x86_64-linux"; outputHashMode = "flat"; outputHashAlgo = "sha1"; outputHash = "sha1-VUCRC+16gU5lcrLYHlPSUyx0Y/Q="; }).outPath"#, "/nix/store/zgpnjjmga53d8srp8chh3m9fn7nnbdv6-foo")]
    #[case::md5(r#"(builtins.derivation { name = "foo"; builder = "/bin/sh"; system = "x86_64-linux"; outputHashMode = "flat"; outputHashAlgo = "md5"; outputHash = "md5-07BzhNET7exJ6qYjitX/AA=="; }).outPath"#, "/nix/store/jfhcwnq1852ccy9ad9nakybp2wadngnd-foo")]
    #[case::sha512(r#"(builtins.derivation { name = "foo"; builder = "/bin/sh"; system = "x86_64-linux"; outputHashMode = "flat"; outputHashAlgo = "sha512"; outputHash = "sha512-DPkYCnZKuoY6Z7bXLwkYvBMcZ3JkLLLc5aNPCnAvlHDdwr8SXBIZixmVwjPDS0r9NGxUojNMNQqUilG26LTmtg=="; }).outPath"#, "/nix/store/as736rr116ian9qzg457f96j52ki8bm3-foo")]
    #[case::outputhash_omitted(r#"(builtins.derivation { name = "foo"; builder = "/bin/sh"; system = "x86_64-linux"; }).outPath"#, "/nix/store/xpcvxsx5sw4rbq666blz6sxqlmsqphmr-foo")]
    #[case::multiple_outputs(r#"(builtins.derivation { name = "foo"; builder = "/bin/sh"; outputs = ["foo" "bar"]; system = "x86_64-linux"; }).outPath"#, "/nix/store/hkwdinvz2jpzgnjy9lv34d2zxvclj4s3-foo-foo")]
    #[case::args(r#"(builtins.derivation { name = "foo"; builder = "/bin/sh"; args = ["--foo" "42" "--bar"]; system = "x86_64-linux"; }).outPath"#, "/nix/store/365gi78n2z7vwc1bvgb98k0a9cqfp6as-foo")]
    #[case::full(r#"
                   let
                     bar = builtins.derivation {
                       name = "bar";
                       builder = ":";
                       system = ":";
                       outputHash = "08813cbee9903c62be4c5027726a418a300da4500b2d369d3af9286f4815ceba";
                       outputHashAlgo = "sha256";
                       outputHashMode = "recursive";
                     };
                   in
                   (builtins.derivation {
                     name = "foo";
                     builder = ":";
                     system = ":";
                     inherit bar;
                   }).outPath
        "#, "/nix/store/5vyvcwah9l9kf07d52rcgdk70g2f4y13-foo")]
    #[case::pass_as_file(r#"(builtins.derivation { "name" = "foo"; passAsFile = ["bar"]; bar = "baz"; system = ":"; builder = ":";}).outPath"#, "/nix/store/25gf0r1ikgmh4vchrn8qlc4fnqlsa5a1-foo")]
    fn test_drvpath(#[case] code: &str, #[case] expected_path: &str) {
        let value = eval(code).value.expect("must succeed");

        match value {
            snix_eval::Value::String(s) => {
                assert_eq!(*s, expected_path);
            }
            _ => panic!("unexpected value type: {value:?}"),
        }
    }

    /// Construct two FODs with the same name, and same known output (but
    /// slightly different recipe), ensure they have the same output hash.
    #[test]
    fn test_fod_outpath() {
        let code = r#"
          (builtins.derivation { name = "foo"; builder = "/bin/sh"; system = "x86_64-linux"; outputHash = "sha256-Q3QXOoy+iN4VK2CflvRulYvPZXYgF0dO7FoF7CvWFTA="; }).outPath ==
          (builtins.derivation { name = "foo"; builder = "/bin/aa"; system = "x86_64-linux"; outputHash = "sha256-Q3QXOoy+iN4VK2CflvRulYvPZXYgF0dO7FoF7CvWFTA="; }).outPath
        "#;

        let value = eval(code).value.expect("must succeed");
        match value {
            snix_eval::Value::Bool(v) => {
                assert!(v);
            }
            _ => panic!("unexpected value type: {value:?}"),
        }
    }

    /// Construct two FODs with the same name, and same known output (but
    /// slightly different recipe), ensure they have the same output hash.
    #[test]
    fn test_fod_outpath_different_name() {
        let code = r#"
          (builtins.derivation { name = "foo"; builder = "/bin/sh"; system = "x86_64-linux"; outputHash = "sha256-Q3QXOoy+iN4VK2CflvRulYvPZXYgF0dO7FoF7CvWFTA="; }).outPath ==
          (builtins.derivation { name = "foo"; builder = "/bin/aa"; system = "x86_64-linux"; outputHash = "sha256-Q3QXOoy+iN4VK2CflvRulYvPZXYgF0dO7FoF7CvWFTA="; }).outPath
        "#;

        let value = eval(code).value.expect("must succeed");
        match value {
            snix_eval::Value::Bool(v) => {
                assert!(v);
            }
            _ => panic!("unexpected value type: {value:?}"),
        }
    }

    /// Construct two derivations with the same parameters except one of them lost a context string
    /// for a dependency, causing the loss of an element in the `inputDrvs` derivation. Therefore,
    /// making `outPath` different.
    #[test]
    fn test_unsafe_discard_string_context() {
        let code = r#"
        let
            dep = builtins.derivation { name = "foo"; builder = "/bin/sh"; system = "x86_64-linux"; };
        in
          (builtins.derivation { name = "foo"; builder = "/bin/sh"; system = "x86_64-linux"; env = "${dep}"; }).outPath !=
          (builtins.derivation { name = "foo"; builder = "/bin/sh"; system = "x86_64-linux"; env = "${builtins.unsafeDiscardStringContext dep}"; }).outPath
        "#;

        let value = eval(code).value.expect("must succeed");
        match value {
            snix_eval::Value::Bool(v) => {
                assert!(v);
            }
            _ => panic!("unexpected value type: {value:?}"),
        }
    }

    /// Construct an attribute set that coerces to a derivation and verify that the return type is
    /// a string.
    #[test]
    fn test_unsafe_discard_string_context_of_coercible() {
        let code = r#"
        let
            dep = builtins.derivation { name = "foo"; builder = "/bin/sh"; system = "x86_64-linux"; };
            attr = { __toString = _: dep; };
        in
            builtins.typeOf (builtins.unsafeDiscardStringContext attr) == "string"
        "#;

        let value = eval(code).value.expect("must succeed");
        match value {
            snix_eval::Value::Bool(v) => {
                assert!(v);
            }
            _ => panic!("unexpected value type: {value:?}"),
        }
    }

    #[rstest]
    #[case::input_in_args(r#"
                   let
                     bar = builtins.derivation {
                       name = "bar";
                       builder = ":";
                       system = ":";
                       outputHash = "08813cbee9903c62be4c5027726a418a300da4500b2d369d3af9286f4815ceba";
                       outputHashAlgo = "sha256";
                       outputHashMode = "recursive";
                     };
                   in
                   (builtins.derivation {
                     name = "foo";
                     builder = ":";
                     args = [ "${bar}" ];
                     system = ":";
                   }).drvPath
        "#, "/nix/store/50yl2gmmljyl0lzyrp1mcyhn53vhjhkd-foo.drv")]
    fn test_inputs_derivation_from_context(#[case] code: &str, #[case] expected_drvpath: &str) {
        let eval_result = eval(code);

        let value = eval_result.value.expect("must succeed");

        match value {
            snix_eval::Value::String(s) => {
                assert_eq!(*s, expected_drvpath);
            }

            _ => panic!("unexpected value type: {value:?}"),
        };
    }

    #[test]
    fn builtins_placeholder_hashes() {
        assert_eq!(
            hash_placeholder("out").as_str(),
            "/1rz4g4znpzjwh1xymhjpm42vipw92pr73vdgl6xs1hycac8kf2n9"
        );

        assert_eq!(
            hash_placeholder("").as_str(),
            "/171rf4jhx57xqz3p7swniwkig249cif71pa08p80mgaf0mqz5bmr"
        );
    }

    /// constructs calls to builtins.derivation that should succeed, but produce warnings
    #[rstest]
    #[case::r_sha256_wrong_padding(r#"(builtins.derivation { name = "foo"; builder = "/bin/sh"; system = "x86_64-linux"; outputHashMode = "recursive"; outputHashAlgo = "sha256"; outputHash = "sha256-fgIr3TyFGDAXP5+qoAaiMKDg/a1MlT6Fv/S/DaA24S8===="; }).outPath"#, "/nix/store/xm1l9dx4zgycv9qdhcqqvji1z88z534b-foo")]
    fn builtins_derivation_hash_wrong_padding_warn(
        #[case] code: &str,
        #[case] expected_path: &str,
    ) {
        let eval_result = eval(code);

        let value = eval_result.value.expect("must succeed");

        match value {
            snix_eval::Value::String(s) => {
                assert_eq!(*s, expected_path);
            }
            _ => panic!("unexpected value type: {value:?}"),
        }

        assert!(
            !eval_result.warnings.is_empty(),
            "warnings should not be empty"
        );
    }
}
