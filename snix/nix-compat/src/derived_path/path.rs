use std::{fmt, str::FromStr};

use crate::store_path;

use super::OutputSpec;

/// A deriving path.
///
/// Deriving paths are a way to refer to store objects that may or may not yet
/// be realised. There are two forms:
///     - opaque: just a store path.
///     - built: a pair of a store path to a store derivation and an output name.
///
/// See: <https://nix.dev/manual/nix/latest/store/derivation/#deriving-path>
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum DerivedPath {
    Opaque(store_path::StorePath<String>),
    Built {
        drv_path: store_path::StorePath<String>,
        outputs: OutputSpec,
    },
}

impl DerivedPath {
    pub fn into_legacy_format(self) -> LegacyDerivedPath {
        LegacyDerivedPath(self)
    }

    pub fn as_legacy_format(&self) -> &LegacyDerivedPath {
        // SAFETY: `DerivedPath` and `LegacyDerivedPath` have the same ABI because of #[repr(transparent)]
        unsafe { &*(self as *const Self as *const LegacyDerivedPath) }
    }
}

impl fmt::Display for DerivedPath {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            DerivedPath::Opaque(store_path) => write!(f, "{}", store_path.to_absolute_path()),
            DerivedPath::Built { drv_path, outputs } => {
                write!(f, "{}^{}", drv_path.to_absolute_path(), outputs)
            }
        }
    }
}

impl FromStr for DerivedPath {
    type Err = store_path::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        if let Some((prefix, outputs_s)) = s.rsplit_once('^') {
            let drv_path = store_path::StorePath::from_absolute_path(prefix.as_bytes())?;
            let outputs = outputs_s.parse::<OutputSpec>()?;
            Ok(DerivedPath::Built { drv_path, outputs })
        } else {
            Ok(DerivedPath::Opaque(
                store_path::StorePath::from_absolute_path(s.as_bytes())?,
            ))
        }
    }
}

/// Format a [`DerivedPath`] in the "legacy" format.
///
/// Normally a [`DerivedPath::Built`] it formatted like
/// `/nix/store/00000000000000000000000000000000-test.drv^out`. But in some
/// places (most notably in the [Nix daemon protocol]) a format like
/// `/nix/store/00000000000000000000000000000000-test.drv!out` is used.
///
/// This formatter implements [`FromStr`] and [`fmt::Display`] that use this format.
///
/// [Nix daemon protocol]: http://snix.dev/docs/reference/nix-daemon-protocol/intro/
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
#[repr(transparent)]
pub struct LegacyDerivedPath(DerivedPath);
impl LegacyDerivedPath {
    pub fn from_path(path: DerivedPath) -> Self {
        path.into_legacy_format()
    }

    pub fn as_path(&self) -> &DerivedPath {
        &self.0
    }

    pub fn into_path(self) -> DerivedPath {
        self.0
    }
}

impl fmt::Display for LegacyDerivedPath {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match &self.0 {
            DerivedPath::Opaque(store_path) => write!(f, "{}", store_path.to_absolute_path()),
            DerivedPath::Built { drv_path, outputs } => {
                write!(f, "{}!{}", drv_path.to_absolute_path(), outputs)
            }
        }
    }
}

impl FromStr for LegacyDerivedPath {
    type Err = store_path::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        if let Some((prefix, outputs_s)) = s.rsplit_once('!') {
            let drv_path = store_path::StorePath::from_absolute_path(prefix.as_bytes())?;
            let outputs = outputs_s.parse::<OutputSpec>()?;
            Ok(LegacyDerivedPath(DerivedPath::Built { drv_path, outputs }))
        } else {
            Ok(LegacyDerivedPath(DerivedPath::Opaque(
                store_path::StorePath::from_absolute_path(s.as_bytes())?,
            )))
        }
    }
}

impl From<DerivedPath> for LegacyDerivedPath {
    fn from(value: DerivedPath) -> Self {
        value.into_legacy_format()
    }
}

impl<'a> From<&'a DerivedPath> for &'a LegacyDerivedPath {
    fn from(value: &'a DerivedPath) -> Self {
        value.as_legacy_format()
    }
}

impl From<LegacyDerivedPath> for DerivedPath {
    fn from(value: LegacyDerivedPath) -> Self {
        value.into_path()
    }
}

impl<'a> From<&'a LegacyDerivedPath> for &'a DerivedPath {
    fn from(value: &'a LegacyDerivedPath) -> Self {
        value.as_path()
    }
}

#[cfg(test)]
mod unittests {
    use rstest::rstest;

    use super::*;

    #[rstest]
    #[case("/nix/store/00000000000000000000000000000000-test.drv", DerivedPath::Opaque("00000000000000000000000000000000-test.drv".parse().unwrap()))]
    #[case("/nix/store/00000000000000000000000000000000-test.drv^out", DerivedPath::Built {
        drv_path: "00000000000000000000000000000000-test.drv".parse().unwrap(),
        outputs: "out".parse().unwrap(),
    })]
    #[case("/nix/store/00000000000000000000000000000000-test.drv^*", DerivedPath::Built {
        drv_path: "00000000000000000000000000000000-test.drv".parse().unwrap(),
        outputs: "*".parse().unwrap(),
    })]
    #[case("/nix/store/00000000000000000000000000000000-test.drv^bin,lib", DerivedPath::Built {
        drv_path: "00000000000000000000000000000000-test.drv".parse().unwrap(),
        outputs: "bin,lib".parse().unwrap(),
    })]
    fn parse_path(#[case] input: &str, #[case] expected: DerivedPath) {
        let actual = input.parse::<DerivedPath>().unwrap();
        assert_eq!(actual, expected);
    }

    #[rstest]
    #[should_panic(expected = "Invalid name")]
    #[case("/nix/store/00000000000000000000000000000000-test.drv^out^bin,lib")]
    #[should_panic(expected = "Invalid name")]
    #[case("/nix/store/00000000000000000000000000000000-test.drv^out^bin^lib")]
    #[should_panic(expected = "Invalid name")]
    #[case("/nix/store/00000000000000000000000000000000-test.drv!out")]
    #[should_panic(expected = "Invalid name")]
    #[case("/nix/store/00000000000000000000000000000000-test.drv!out^bin")]
    #[should_panic(expected = "Invalid name")]
    #[case("/nix/store/00000000000000000000000000000000-test.drv^out^bin!out^lib")]
    fn parse_path_failure(#[case] input: &str) {
        let actual = input.parse::<DerivedPath>().unwrap_err();
        panic!("{actual}");
    }

    #[rstest]
    #[case("/nix/store/00000000000000000000000000000000-test.drv", DerivedPath::Opaque("00000000000000000000000000000000-test.drv".parse().unwrap()))]
    #[case("/nix/store/00000000000000000000000000000000-test.drv!out", DerivedPath::Built {
        drv_path: "00000000000000000000000000000000-test.drv".parse().unwrap(),
        outputs: "out".parse().unwrap(),
    })]
    #[case("/nix/store/00000000000000000000000000000000-test.drv!*", DerivedPath::Built {
        drv_path: "00000000000000000000000000000000-test.drv".parse().unwrap(),
        outputs: "*".parse().unwrap(),
    })]
    #[case("/nix/store/00000000000000000000000000000000-test.drv!bin,lib", DerivedPath::Built {
        drv_path: "00000000000000000000000000000000-test.drv".parse().unwrap(),
        outputs: "bin,lib".parse().unwrap(),
    })]
    fn parse_legacy_path(#[case] input: &str, #[case] expected: DerivedPath) {
        let actual = input.parse::<LegacyDerivedPath>().unwrap().into_path();
        assert_eq!(actual, expected);
    }

    #[rstest]
    #[should_panic(expected = "Invalid name")]
    #[case("/nix/store/00000000000000000000000000000000-test.drv!out!bin,lib")]
    #[should_panic(expected = "Invalid name")]
    #[case("/nix/store/00000000000000000000000000000000-test.drv!out!bin!lib")]
    #[should_panic(expected = "Invalid name")]
    #[case("/nix/store/00000000000000000000000000000000-test.drv^out")]
    #[should_panic(expected = "Invalid name")]
    #[case("/nix/store/00000000000000000000000000000000-test.drv^out!bin")]
    #[should_panic(expected = "Invalid name")]
    #[case("/nix/store/00000000000000000000000000000000-test.drv!out!bin^out!lib")]
    fn parse_legacy_path_failure(#[case] input: &str) {
        let actual = input.parse::<LegacyDerivedPath>().unwrap_err();
        panic!("{actual}");
    }

    #[rstest]
    #[case(DerivedPath::Opaque("00000000000000000000000000000000-test.drv".parse().unwrap()), "/nix/store/00000000000000000000000000000000-test.drv")]
    #[case(DerivedPath::Built {
        drv_path: "00000000000000000000000000000000-test.drv".parse().unwrap(),
        outputs: "out".parse().unwrap(),
    }, "/nix/store/00000000000000000000000000000000-test.drv^out")]
    #[case(DerivedPath::Built {
        drv_path: "00000000000000000000000000000000-test.drv".parse().unwrap(),
        outputs: "*".parse().unwrap(),
    }, "/nix/store/00000000000000000000000000000000-test.drv^*")]
    #[case(DerivedPath::Built {
        drv_path: "00000000000000000000000000000000-test.drv".parse().unwrap(),
        outputs: "bin,lib".parse().unwrap(),
    }, "/nix/store/00000000000000000000000000000000-test.drv^bin,lib")]
    fn display_path(#[case] value: DerivedPath, #[case] expected: &str) {
        assert_eq!(value.to_string(), expected);
    }

    #[rstest]
    #[case(DerivedPath::Opaque("00000000000000000000000000000000-test.drv".parse().unwrap()), "/nix/store/00000000000000000000000000000000-test.drv")]
    #[case(DerivedPath::Built {
        drv_path: "00000000000000000000000000000000-test.drv".parse().unwrap(),
        outputs: "out".parse().unwrap(),
    }, "/nix/store/00000000000000000000000000000000-test.drv!out")]
    #[case(DerivedPath::Built {
        drv_path: "00000000000000000000000000000000-test.drv".parse().unwrap(),
        outputs: "*".parse().unwrap(),
    }, "/nix/store/00000000000000000000000000000000-test.drv!*")]
    #[case(DerivedPath::Built {
        drv_path: "00000000000000000000000000000000-test.drv".parse().unwrap(),
        outputs: "bin,lib".parse().unwrap(),
    }, "/nix/store/00000000000000000000000000000000-test.drv!bin,lib")]
    fn display_legacy_path(#[case] value: DerivedPath, #[case] expected: &str) {
        assert_eq!(value.as_legacy_format().to_string(), expected);
    }
}
