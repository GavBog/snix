use std::{fmt, str::FromStr};

use crate::store_path;

/// A derivation output name.
///
/// This is a derivation output name, so the 'out' or 'bin' bit that has
/// been verified to not contain invalid characters.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash)]
#[cfg_attr(
    feature = "serde",
    derive(serde_with::DeserializeFromStr, serde_with::SerializeDisplay)
)]
pub struct OutputName(String);

impl OutputName {
    /// Returns `true` if this output name is the default of `out`.
    pub fn is_default(&self) -> bool {
        self.0 == "out"
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }

    pub fn into_string(self) -> String {
        self.0
    }
}

fn parse<S: AsRef<str> + Into<String>>(s: S) -> Result<OutputName, ParseOutputNameError> {
    store_path::validate_name(s.as_ref())?;

    // Disallow the reserved 'drv' name, which may appear in store path names,
    // but not in Derivations.
    if s.as_ref() == "drv" {
        return Err(ParseOutputNameError::ReservedNameDrv);
    }

    Ok(OutputName(s.into()))
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
    type Err = ParseOutputNameError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        parse(s)
    }
}

impl TryFrom<String> for OutputName {
    type Error = ParseOutputNameError;

    fn try_from(value: String) -> Result<Self, Self::Error> {
        parse(value)
    }
}

impl From<OutputName> for String {
    fn from(value: OutputName) -> Self {
        value.0
    }
}

#[derive(thiserror::Error, Debug)]
pub enum ParseOutputNameError {
    #[error("Invalid length")]
    InvalidLength,
    #[error("Invalid name")]
    InvalidName,
    #[error("Invalid reserved name 'drv'")]
    ReservedNameDrv,
}

impl From<store_path::ParseStorePathNameError> for ParseOutputNameError {
    fn from(value: store_path::ParseStorePathNameError) -> Self {
        match value {
            store_path::ParseStorePathNameError::Length => ParseOutputNameError::InvalidLength,
            store_path::ParseStorePathNameError::Name => ParseOutputNameError::InvalidName,
        }
    }
}

#[cfg(test)]
mod tests {
    use rstest::rstest;

    use super::OutputName;

    #[rstest]
    #[should_panic(expected = "InvalidName")]
    #[case("bin{n")]
    #[should_panic(expected = "InvalidName")]
    #[case("bin{n")]
    #[should_panic(expected = "InvalidName")]
    #[case(" bin{n")]
    #[should_panic(expected = "ReservedNameDrv")]
    #[case("drv")]
    #[should_panic(expected = "InvalidLength")]
    #[case("")]
    fn parse_fail(#[case] value: &str) {
        value.parse::<OutputName>().unwrap();
    }
}
