//! This module implements the serialisation of derivations into the
//! [ATerm][] format used by C++ Nix.
//!
//! [ATerm]: http://program-transformation.org/Tools/ATermFormat.html

use super::{ca_kind_prefix, output::Output};
use crate::derivation::OutputName;
use crate::store_path::{StorePath, StorePathRef};
use crate::{aterm::write_escaped, derivation::Derivation};
use data_encoding::HEXLOWER;

use std::{
    collections::{BTreeMap, BTreeSet},
    io,
    io::Error,
    io::Write,
};

pub const DERIVATION_PREFIX: &str = "Derive";
pub const PAREN_OPEN: char = '(';
pub const PAREN_CLOSE: char = ')';
pub const BRACKET_OPEN: char = '[';
pub const BRACKET_CLOSE: char = ']';
pub const COMMA: char = ',';
pub const QUOTE: char = '"';

/// Something that can be written as ATerm.
///
/// Note that we mostly use explicit `write_*` calls
/// instead since the serialization of the items depends on
/// the context a lot.
pub(super) trait AtermWriteable {
    fn aterm_write(&self, writer: &mut impl io::Write) -> std::io::Result<()>;
}

impl<'a> AtermWriteable for &StorePathRef<'a> {
    fn aterm_write(&self, writer: &mut impl Write) -> std::io::Result<()> {
        write_char(writer, QUOTE)?;
        write!(writer, "{}", self.as_absolute_path_fmt())?;
        write_char(writer, QUOTE)?;
        Ok(())
    }
}

impl AtermWriteable for &StorePath {
    fn aterm_write(&self, writer: &mut impl Write) -> std::io::Result<()> {
        (&self.as_ref()).aterm_write(writer)
    }
}

impl AtermWriteable for &String {
    fn aterm_write(&self, writer: &mut impl Write) -> std::io::Result<()> {
        write_field(writer, self, true)
    }
}
impl AtermWriteable for &str {
    fn aterm_write(&self, writer: &mut impl Write) -> std::io::Result<()> {
        write_field(writer, self, true)
    }
}

impl AtermWriteable for &[u8] {
    fn aterm_write(&self, writer: &mut impl Write) -> std::io::Result<()> {
        write_field(writer, HEXLOWER.encode(self), false)
    }
}

impl AtermWriteable for [u8] {
    fn aterm_write(&self, writer: &mut impl Write) -> std::io::Result<()> {
        write_field(writer, HEXLOWER.encode(self), false)
    }
}

impl AtermWriteable for [u8; 32] {
    fn aterm_write(&self, writer: &mut impl Write) -> std::io::Result<()> {
        write_field(writer, HEXLOWER.encode(self), false)
    }
}

impl AtermWriteable for &OutputName {
    fn aterm_write(&self, writer: &mut impl io::Write) -> std::io::Result<()> {
        write_field(writer, self.as_ref(), false)
    }
}

impl Derivation {
    /// Like `serialize`, but allows replacing the input_derivations for hash calculations.
    ///
    /// This is used to render the ATerm representation of a Derivation "modulo
    /// fixed-output derivations".
    ///
    /// The passed input_derivations MUST be sorted.
    pub(super) fn serialize_with_replacements<'a, K, I>(
        &self,
        writer: &mut impl std::io::Write,
        input_derivations_sorted: I,
    ) -> Result<(), io::Error>
    where
        I: Iterator<Item = (K, &'a BTreeSet<OutputName>)>,
        K: AtermWriteable,
    {
        writer.write_all(DERIVATION_PREFIX.as_bytes())?;
        write_char(writer, PAREN_OPEN)?;

        write_outputs(writer, &self.outputs)?;
        write_char(writer, COMMA)?;

        write_input_derivations(writer, input_derivations_sorted)?;
        write_char(writer, COMMA)?;

        write_input_sources(writer, &self.input_sources)?;
        write_char(writer, COMMA)?;

        write_system(writer, &self.system)?;
        write_char(writer, COMMA)?;

        write_builder(writer, &self.builder)?;
        write_char(writer, COMMA)?;

        write_arguments(writer, &self.arguments)?;
        write_char(writer, COMMA)?;

        write_environment(writer, &self.environment)?;

        write_char(writer, PAREN_CLOSE)?;

        Ok(())
    }
}

// Writes a character to the writer.
pub(crate) fn write_char(writer: &mut impl Write, c: char) -> io::Result<()> {
    let mut buf = [0; 4];
    let b = c.encode_utf8(&mut buf).as_bytes();
    writer.write_all(b)
}

// Write a string `s` as a quoted field to the writer.
// The `escape` argument controls whether escaping will be skipped.
// This is the case if `s` is known to only contain characters that need no
// escaping.
pub(crate) fn write_field<S: AsRef<[u8]>>(
    writer: &mut impl Write,
    s: S,
    escape: bool,
) -> io::Result<()> {
    write_char(writer, QUOTE)?;

    if !escape {
        writer.write_all(s.as_ref())?;
    } else {
        write_escaped(s, writer)?;
    }

    write_char(writer, QUOTE)?;

    Ok(())
}

fn write_array_elements<S>(
    writer: &mut impl Write,
    elements: impl IntoIterator<Item = S>,
) -> Result<(), io::Error>
where
    S: AtermWriteable,
{
    for (index, element) in elements.into_iter().enumerate() {
        if index > 0 {
            write_char(writer, COMMA)?;
        }

        element.aterm_write(writer)?;
    }

    Ok(())
}

fn write_outputs(
    writer: &mut impl Write,
    outputs: &BTreeMap<OutputName, Output>,
) -> Result<(), io::Error> {
    write_char(writer, BRACKET_OPEN)?;
    for (ii, (output_name, output)) in outputs.iter().enumerate() {
        if ii > 0 {
            write_char(writer, COMMA)?;
        }

        write_char(writer, PAREN_OPEN)?;

        let path_str = output.path_str();

        if let Some(ca_hash) = &output.ca_hash {
            let mode_and_algo = &format!("{}{}", ca_kind_prefix(ca_hash), ca_hash.hash().algo());
            let digest_str = &data_encoding::HEXLOWER.encode(ca_hash.hash().digest_as_bytes());
            write_array_elements(
                writer,
                [
                    output_name.as_str(),
                    path_str.as_ref(),
                    mode_and_algo,
                    digest_str,
                ],
            )?;
        } else {
            write_array_elements(writer, [output_name.as_str(), path_str.as_ref(), "", ""])?;
        };

        write_char(writer, PAREN_CLOSE)?;
    }
    write_char(writer, BRACKET_CLOSE)?;

    Ok(())
}

fn write_input_derivations<'a, I, K>(
    writer: &mut impl Write,
    input_derivations_sorted: I,
) -> Result<(), io::Error>
where
    I: Iterator<Item = (K, &'a BTreeSet<OutputName>)>,
    K: AtermWriteable,
{
    write_char(writer, BRACKET_OPEN)?;

    for (ii, (k, output_names)) in input_derivations_sorted.enumerate() {
        if ii > 0 {
            write_char(writer, COMMA)?;
        }

        write_char(writer, PAREN_OPEN)?;
        k.aterm_write(writer)?;
        write_char(writer, COMMA)?;

        write_char(writer, BRACKET_OPEN)?;
        write_array_elements(writer, output_names)?;
        write_char(writer, BRACKET_CLOSE)?;

        write_char(writer, PAREN_CLOSE)?;
    }

    write_char(writer, BRACKET_CLOSE)?;

    Ok(())
}

fn write_input_sources(
    writer: &mut impl Write,
    input_sources: &BTreeSet<StorePath>,
) -> Result<(), io::Error> {
    write_char(writer, BRACKET_OPEN)?;
    write_array_elements(writer, input_sources)?;
    write_char(writer, BRACKET_CLOSE)?;

    Ok(())
}

fn write_system(writer: &mut impl Write, platform: &str) -> Result<(), Error> {
    write_field(writer, platform, true)?;
    Ok(())
}

fn write_builder(writer: &mut impl Write, builder: &str) -> Result<(), Error> {
    write_field(writer, builder, true)?;
    Ok(())
}

fn write_arguments(writer: &mut impl Write, arguments: &[String]) -> Result<(), io::Error> {
    write_char(writer, BRACKET_OPEN)?;
    write_array_elements(writer, arguments)?;
    write_char(writer, BRACKET_CLOSE)?;

    Ok(())
}

fn write_environment<E, K, V>(writer: &mut impl Write, environment: E) -> Result<(), io::Error>
where
    E: IntoIterator<Item = (K, V)>,
    K: AsRef<[u8]>,
    V: AsRef<[u8]>,
{
    write_char(writer, BRACKET_OPEN)?;

    for (i, (k, v)) in environment.into_iter().enumerate() {
        if i > 0 {
            write_char(writer, COMMA)?;
        }

        write_char(writer, PAREN_OPEN)?;
        write_field(writer, k, false)?;
        write_char(writer, COMMA)?;
        write_field(writer, v, true)?;
        write_char(writer, PAREN_CLOSE)?;
    }

    write_char(writer, BRACKET_CLOSE)?;

    Ok(())
}
