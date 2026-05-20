use serde::Deserialize;
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(knus::Decode, Debug)]
pub struct TestCase {
    #[knus(child, default)]
    pub lang: Lang,

    #[knus(child, default)]
    pub environment: Environment,

    #[knus(child, default)]
    pub runtime_opts: RuntimeOpts,
}

#[derive(knus::Decode, Debug, Default)]
pub struct Lang {
    #[knus(child, default, unwrap(arguments))]
    pub builtins: HashSet<String>,

    #[knus(child, default, unwrap(arguments))]
    pub features: HashSet<Feature>,
}

#[derive(knus::Decode, Debug, Default)]
pub struct Environment {
    #[knus(child, default, unwrap(children))]
    pub fixtures: Vec<Fixture>,

    #[knus(child, unwrap(argument))]
    pub work_dir: Option<String>,

    #[knus(child, default)]
    pub network: bool,

    #[knus(child, default)]
    pub nix_store: bool,

    #[knus(children(name = "env-var"))]
    pub env_vars: Vec<EnvVar>,
}

#[derive(knus::Decode, Debug)]
pub struct EnvVar {
    #[knus(argument)]
    pub name: String,

    #[knus(argument)]
    pub value: String,
}

#[derive(knus::Decode, Default, Debug)]
pub struct RuntimeOpts {
    #[knus(child)]
    pub eval_strict: bool,

    #[knus(child)]
    pub xml_output: bool,

    #[knus(child, default, unwrap(arguments))]
    pub search_path: Vec<String>,
}

#[derive(Debug, PartialEq, Eq)]
pub enum ErrorKind {
    IO,
    NotCoercibleToString,
    TypeError,
}

impl std::str::FromStr for ErrorKind {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "IO" => Ok(ErrorKind::IO),
            "NotCoercibleToString" => Ok(ErrorKind::NotCoercibleToString),
            "TypeError" => Ok(ErrorKind::TypeError),
            other => Err(format!("unknown error kind: {other}")),
        }
    }
}

#[derive(knus::Decode, Debug)]
pub enum Fixture {
    File(FileFixture),
    Dir(DirFixture),
    Device(DeviceFixture),
}

#[derive(knus::Decode, Debug)]
pub struct FileFixture {
    #[knus(argument)]
    path: PathBuf,

    #[knus(property(name = "ref"))]
    r#ref: Option<PathBuf>,

    #[knus(property(name = "content"))]
    content: Option<String>,

    #[knus(property(name = "symlink"))]
    symlink: Option<PathBuf>,
}

#[derive(knus::Decode, Debug)]
pub struct DirFixture {
    #[knus(argument)]
    path: PathBuf,

    #[knus(property(name = "ref"))]
    r#ref: Option<PathBuf>,

    #[knus(property(name = "symlink"))]
    symlink: Option<PathBuf>,

    #[knus(children)]
    entries: Vec<Fixture>,
}

#[derive(knus::Decode, Debug)]
pub struct DeviceFixture {
    #[knus(argument)]
    _path: PathBuf,
}

#[derive(Deserialize, Debug, Default)]
pub struct Flags {
    #[serde(default)]
    pub eval_strict: bool,

    #[serde(default)]
    pub xml_output: bool,

    #[serde(default)]
    pub search_path: Vec<String>,
}

#[derive(Debug, PartialEq, Eq, Hash)]
pub enum Feature {
    Flakes,
    PipeOperators,
    PathInterpolation,
    Curpos,
    Corepkgs,
}

impl std::str::FromStr for Feature {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "flakes" => Ok(Feature::Flakes),
            "pipe-operators" => Ok(Feature::PipeOperators),
            "path-interpolation" => Ok(Feature::PathInterpolation),
            "curpos" => Ok(Feature::Curpos),
            "corepkgs" => Ok(Feature::Corepkgs),
            other => Err(format!("unknown feature: {other}")),
        }
    }
}

impl<S: knus::traits::ErrorSpan> knus::traits::DecodeScalar<S> for Feature {
    fn type_check(
        type_name: &Option<knus::span::Spanned<knus::ast::TypeName, S>>,
        ctx: &mut knus::decode::Context<S>,
    ) {
        <String as knus::traits::DecodeScalar<S>>::type_check(type_name, ctx);
    }

    fn raw_decode(
        value: &knus::span::Spanned<knus::ast::Literal, S>,
        ctx: &mut knus::decode::Context<S>,
    ) -> Result<Self, knus::errors::DecodeError<S>> {
        let s = <String as knus::traits::DecodeScalar<S>>::raw_decode(value, ctx)?;
        s.parse::<Feature>()
            .map_err(|e| knus::errors::DecodeError::conversion(value, e))
    }
}

/// Normalize the output string by replacing absolute paths with configured values.
pub fn normalize_output(test_case: &TestCase, code_path: &Path, output: &str) -> String {
    let mut s = output.to_string();

    if let Some(work_dir) = &test_case.environment.work_dir {
        let pwd = code_path
            .parent()
            .expect("unable to get code file's dir")
            .to_str()
            .unwrap();
        s = s.replace(pwd, work_dir);
    }

    if let Some(env_var) = test_case
        .environment
        .env_vars
        .iter()
        .find(|v| v.name == "HOME")
    {
        let pwd = std::env::home_dir().expect("failed to find home dir");
        s = s.replace(&pwd.to_string_lossy().to_string(), &env_var.value);
    }

    s
}

pub fn load_test_case(path: &Path) -> TestCase {
    let buf = std::fs::read_to_string(path).expect("should be able to read test case file");
    knus::parse::<TestCase>(path.to_string_lossy(), &buf)
        .expect("test case should be a valid KDL file")
}

/// Load expected output from a `.exp` file adjacent to the test case.
pub fn load_expected_output(test_case_path: &Path) -> Option<String> {
    let exp_path = test_case_path.with_extension("exp");
    if exp_path.exists() {
        Some(fs::read_to_string(&exp_path).expect("couldn't read .exp file"))
    } else {
        None
    }
}

/// Load expected error kind from a `.err` file adjacent to the test case.
pub fn load_expected_error(test_case_path: &Path) -> Option<ErrorKind> {
    let err_path = test_case_path.with_extension("err");
    if err_path.exists() {
        let s = fs::read_to_string(&err_path).expect("couldn't read .err file");
        Some(s.trim().parse().unwrap())
    } else {
        None
    }
}

/// Set up a temporary directory with fixtures and a copy of the test's `.nix` file.
pub fn setup_environment(
    test_case_path: &Path,
    test_case: &TestCase,
) -> (tempfile::TempDir, PathBuf) {
    let tmp_dir = tempfile::tempdir().unwrap();

    setup_fixtures(
        test_case_path.parent().unwrap(),
        tmp_dir.path(),
        &test_case.environment.fixtures,
    );

    let code_path = test_case_path.with_extension("nix");
    let tmp_code_path = tmp_dir.path().join(code_path.file_name().unwrap());
    fs::copy(code_path, &tmp_code_path).unwrap();

    (tmp_dir, tmp_code_path)
}

fn setup_fixtures(case_path: &Path, parent: &Path, fixtures: &[Fixture]) {
    for fixture in fixtures {
        match fixture {
            Fixture::File(file) => {
                let full_path = parent.join(&file.path);

                match (&file.content, &file.r#ref, &file.symlink) {
                    (Some(content), None, None) => {
                        fs::write(&full_path, content).unwrap();
                    }
                    (None, Some(r#ref), None) => {
                        let src = case_path.join(r#ref);
                        fs::copy(&src, &full_path).unwrap();
                    }
                    (None, None, Some(symlink)) => {
                        let target = parent.join(symlink);
                        std::os::unix::fs::symlink(target, full_path).unwrap();
                    }
                    _ => panic!("file fixture is ambiguos: {:?}", file),
                };
            }
            Fixture::Dir(dir) => {
                let full_path = parent.join(&dir.path);

                match (
                    &dir.r#ref,
                    &dir.symlink,
                    (!dir.entries.is_empty()).then_some(&dir.entries),
                ) {
                    (Some(r#ref), None, None) => {
                        let src = case_path.join(r#ref);
                        copy_dir(&src, &full_path).unwrap();
                    }
                    (None, Some(symlink), None) => {
                        let target = parent.join(symlink);
                        std::os::unix::fs::symlink(target, full_path).unwrap();
                    }
                    (None, None, Some(entries)) => {
                        fs::create_dir_all(&full_path).unwrap();
                        setup_fixtures(case_path, &full_path, entries);
                    }
                    (None, None, None) => fs::create_dir_all(&full_path).unwrap(),
                    _ => panic!("dir fixture is ambiguos: {:?}", dir),
                }
            }
            Fixture::Device(_) => {}
        }
    }
}

fn copy_dir(src: &Path, dst: &Path) -> std::io::Result<()> {
    fs::create_dir_all(dst)?;

    for entry in fs::read_dir(src)? {
        let entry = entry?;
        let src_path = entry.path();
        let dst_path = dst.join(entry.file_name());

        if src_path.is_dir() {
            copy_dir(&src_path, &dst_path)?;
        } else {
            std::fs::copy(src_path, dst_path)?;
        }
    }

    Ok(())
}
