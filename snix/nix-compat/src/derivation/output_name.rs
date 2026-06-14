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
    type Err = store_path::ValidateNameError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let name = store_path::validate_name(&s)?.to_string();
        Ok(OutputName(name))
    }
}
