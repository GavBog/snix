use crate::derivation::{Derivation, DerivationError, OutputName};

impl Derivation {
    /// validate ensures a Derivation struct is properly populated,
    /// and returns a [DerivationError] if not.
    ///
    /// This is helpful to validate struct population before invoking
    /// [Derivation::calculate_output_paths].
    pub fn validate(&self) -> Result<(), DerivationError> {
        // Ensure the number of outputs is > 1
        if self.outputs.is_empty() {
            return Err(DerivationError::NoOutputs());
        }

        // Validate all outputs
        for (output_name, output) in &self.outputs {
            if output.is_fixed() {
                if self.outputs.len() != 1 {
                    return Err(DerivationError::MoreThanOneOutputButFixed());
                }
                if *output_name != OutputName::out() {
                    return Err(DerivationError::InvalidOutputNameForFixed(
                        output_name.to_string(),
                    ));
                }
            }
        }

        // Validate all input_derivation paths to end with .drv.
        // The output names are already validated as we're using the OutputName type.
        for input_derivation_path in self.input_derivations.keys() {
            if !input_derivation_path.name().ends_with(".drv") {
                return Err(DerivationError::InvalidInputDerivationPrefix(
                    input_derivation_path.to_string(),
                ));
            }
        }

        // validate platform
        if self.system.is_empty() {
            return Err(DerivationError::InvalidPlatform(self.system.to_string()));
        }

        // validate builder
        if self.builder.is_empty() {
            return Err(DerivationError::InvalidBuilder(self.builder.to_string()));
        }

        // validate env, none of the keys may be empty.
        // We skip the `name` validation seen in go-nix.
        for k in self.environment.keys() {
            if k.is_empty() {
                return Err(DerivationError::InvalidEnvironmentKey(k.to_string()));
            }
        }

        Ok(())
    }
}
