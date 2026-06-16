use crate::derivation::{Derivation, DerivationError, OutputName};

impl Derivation {
    /// validate ensures a Derivation struct is properly populated,
    /// and returns a [DerivationError] if not.
    ///
    /// if `validate_output_paths` is set to false, the output paths are
    /// excluded from validation.
    ///
    /// This is helpful to validate struct population before invoking
    /// [Derivation::calculate_output_paths].
    pub fn validate(&self, validate_output_paths: bool) -> Result<(), DerivationError> {
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

            if let Err(e) = output.validate(validate_output_paths) {
                return Err(DerivationError::InvalidOutput(output_name.to_string(), e));
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

#[cfg(test)]
mod test {
    use std::collections::BTreeMap;

    use crate::derivation::{CAHash, Derivation, Output, OutputName};

    /// Regression test: produce a Derivation that's almost valid, except its
    /// fixed-output output has the wrong hash specified.
    #[test]
    fn output_validate() {
        let mut outputs = BTreeMap::new();
        outputs.insert(
            OutputName::out(),
            Output {
                path: None,
                ca_hash: Some(CAHash::Text([0; 32])), // This is disallowed
            },
        );

        let drv = Derivation {
            arguments: vec![],
            builder: "/bin/sh".to_string(),
            outputs,
            system: "x86_64-linux".to_string(),
            ..Default::default()
        };

        drv.validate(false).expect_err("must fail");
    }
}
