use std::collections::BTreeSet;
use std::fmt;
use std::str::FromStr;

use crate::store_path::{ValidateNameError, validate_name};

/// A derivation output name.
///
/// This is a derivation output name, so the 'out' or 'bin' bit that has
/// been verified to not contain invalid characters.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash)]
#[cfg_attr(
    feature = "serde",
    derive(serde_with::DeserializeFromStr, serde_with::SerializeDisplay)
)]
pub struct OutputName(pub(crate) String);

impl OutputName {
    /// Returns `true` if this output name is the default of `out`.
    pub fn is_default(&self) -> bool {
        self.0 == "out"
    }
}

impl fmt::Display for OutputName {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

impl AsRef<str> for OutputName {
    fn as_ref(&self) -> &str {
        &self.0
    }
}

impl Default for OutputName {
    fn default() -> Self {
        OutputName("out".into())
    }
}

impl FromStr for OutputName {
    type Err = ValidateNameError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let name = validate_name(&s)?.to_string();
        Ok(OutputName(name))
    }
}

// FUTUREWORK: reduce the amount of heap allocation needed for this small set of small strings.
/// An output selection spec.
///
/// This is either all outputs (formatted as '*' when displaying or parsing) or
/// a set of [`OutputName`] with the outputs that is to be selected.
///
/// This is used in [`super::DerivedPath`] to perform selection of the outputs to make
/// sure, while building, are valid or substituted.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash)]
#[cfg_attr(
    feature = "serde",
    derive(serde_with::DeserializeFromStr, serde_with::SerializeDisplay)
)]
pub enum OutputSpec {
    All,
    Named(BTreeSet<OutputName>),
}

impl OutputSpec {
    pub fn single(output_name: OutputName) -> Self {
        let mut set = BTreeSet::new();
        set.insert(output_name);
        Self::Named(set)
    }
}

impl fmt::Display for OutputSpec {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            OutputSpec::All => f.write_str("*")?,
            OutputSpec::Named(outputs) => {
                let mut it = outputs.iter();
                if let Some(output) = it.next() {
                    write!(f, "{output}")?;
                    for output in it {
                        write!(f, ",{output}")?;
                    }
                }
            }
        }
        Ok(())
    }
}

impl FromStr for OutputSpec {
    type Err = ValidateNameError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        if s == "*" {
            Ok(OutputSpec::All)
        } else {
            let mut outputs = BTreeSet::new();
            for name in s.split(",") {
                let output = name.parse()?;
                outputs.insert(output);
            }
            Ok(OutputSpec::Named(outputs))
        }
    }
}

impl From<OutputName> for OutputSpec {
    fn from(output_name: OutputName) -> Self {
        Self::single(output_name)
    }
}

#[cfg(test)]
mod unittests {
    use rstest::rstest;

    use crate::derived_path::OutputSpec;

    #[macro_export]
    macro_rules! set {
        () => { BTreeSet::new() };
        ($($x:expr),+ $(,)?) => {{
            let mut ret = std::collections::BTreeSet::new();
            $(
                ret.insert($x.parse().unwrap());
            )+
            ret
        }};
    }

    #[rstest]
    #[case("*", OutputSpec::All)]
    #[case("out", OutputSpec::Named(set!("out")))]
    #[case("bin,dev,out", OutputSpec::Named(set!("bin", "dev", "out")))]
    fn parse(#[case] value: &str, #[case] expected: OutputSpec) {
        let actual = value.parse::<OutputSpec>().unwrap();
        assert_eq!(actual, expected);
    }

    #[rstest]
    #[should_panic(expected = "Invalid name")]
    #[case("bin{n")]
    #[should_panic(expected = "Invalid name")]
    #[case("out,bin{n")]
    #[should_panic(expected = "Invalid name")]
    #[case(" bin{n")]
    #[should_panic(expected = "Invalid length")]
    #[case("out,")]
    #[should_panic(expected = "Invalid length")]
    #[case("")]
    #[should_panic(expected = "Invalid length")]
    #[case(",out")]
    #[should_panic(expected = "Invalid length")]
    #[case::too_long(
        "test-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    )]
    fn parse_failure(#[case] value: &str) {
        let actual = value.parse::<OutputSpec>().unwrap_err();
        panic!("{actual}");
    }

    #[rstest]
    #[case(OutputSpec::All, "*")]
    #[case(OutputSpec::Named(set!("out")), "out")]
    #[case(OutputSpec::Named(set!("bin", "dev", "out")), "bin,dev,out")]
    fn display(#[case] value: OutputSpec, #[case] expected: &str) {
        assert_eq!(value.to_string(), expected);
    }
}
