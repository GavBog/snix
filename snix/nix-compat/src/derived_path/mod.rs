use std::{fmt, str::FromStr};

mod legacy;
mod output_spec;

pub use legacy::LegacyDerivedPath;
pub use output_spec::{OutputName, OutputSpec};

use crate::store_path;

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
        LegacyDerivedPath::from_path(self)
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

#[cfg(test)]
mod tests {
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
    fn parse(#[case] input: &str, #[case] expected: DerivedPath) {
        let actual = input.parse::<DerivedPath>().unwrap();
        assert_eq!(actual, expected);
    }

    #[rstest]
    #[should_panic(expected = "InvalidName")]
    #[case("/nix/store/00000000000000000000000000000000-test.drv^out^bin,lib")]
    #[should_panic(expected = "InvalidName")]
    #[case("/nix/store/00000000000000000000000000000000-test.drv^out^bin^lib")]
    #[should_panic(expected = "InvalidName")]
    #[case("/nix/store/00000000000000000000000000000000-test.drv!out")]
    #[should_panic(expected = "InvalidName")]
    #[case("/nix/store/00000000000000000000000000000000-test.drv!out^bin")]
    #[should_panic(expected = "InvalidName")]
    #[case("/nix/store/00000000000000000000000000000000-test.drv^out^bin!out^lib")]
    fn parse_fail(#[case] input: &str) {
        input.parse::<DerivedPath>().unwrap();
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
    fn display(#[case] value: DerivedPath, #[case] expected: &str) {
        assert_eq!(value.to_string(), expected);
    }
}
