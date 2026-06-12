//! This module implements the serialisation of derivations into the
//! [ATerm][] format used by C++ Nix.
//!
//! [ATerm]: http://program-transformation.org/Tools/ATermFormat.html

use crate::aterm::write_escaped;
use crate::derivation::{ca_kind_prefix, output::Output};
use crate::store_path::StorePath;
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
pub(crate) trait AtermWriteable {
    fn aterm_write(&self, writer: &mut impl Write) -> std::io::Result<()>;
}

impl<S> AtermWriteable for &StorePath<S>
where
    S: AsRef<str>,
{
    fn aterm_write(&self, writer: &mut impl Write) -> std::io::Result<()> {
        write_char(writer, QUOTE)?;
        write!(writer, "{}", self.as_absolute_path_fmt())?;
        write_char(writer, QUOTE)?;
        Ok(())
    }
}

impl<S> AtermWriteable for StorePath<S>
where
    S: AsRef<str>,
{
    fn aterm_write(&self, writer: &mut impl Write) -> std::io::Result<()> {
        (&self).aterm_write(writer)
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

pub(crate) fn write_outputs(
    writer: &mut impl Write,
    outputs: &BTreeMap<String, Output>,
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
                [output_name, path_str.as_ref(), mode_and_algo, digest_str],
            )?;
        } else {
            write_array_elements(writer, [output_name, path_str.as_ref(), "", ""])?;
        };

        write_char(writer, PAREN_CLOSE)?;
    }
    write_char(writer, BRACKET_CLOSE)?;

    Ok(())
}

pub(crate) fn write_input_derivations(
    writer: &mut impl Write,
    input_derivations: &BTreeMap<impl AtermWriteable, BTreeSet<String>>,
) -> Result<(), io::Error> {
    write_char(writer, BRACKET_OPEN)?;

    for (ii, (input_derivation_aterm, output_names)) in input_derivations.iter().enumerate() {
        if ii > 0 {
            write_char(writer, COMMA)?;
        }

        write_char(writer, PAREN_OPEN)?;
        input_derivation_aterm.aterm_write(writer)?;
        write_char(writer, COMMA)?;

        write_char(writer, BRACKET_OPEN)?;
        write_array_elements(writer, output_names)?;
        write_char(writer, BRACKET_CLOSE)?;

        write_char(writer, PAREN_CLOSE)?;
    }

    write_char(writer, BRACKET_CLOSE)?;

    Ok(())
}

pub(crate) fn write_input_sources(
    writer: &mut impl Write,
    input_sources: &BTreeSet<StorePath<String>>,
) -> Result<(), io::Error> {
    write_char(writer, BRACKET_OPEN)?;
    write_array_elements(writer, input_sources)?;
    write_char(writer, BRACKET_CLOSE)?;

    Ok(())
}

pub(crate) fn write_system(writer: &mut impl Write, platform: &str) -> Result<(), Error> {
    write_field(writer, platform, true)?;
    Ok(())
}

pub(crate) fn write_builder(writer: &mut impl Write, builder: &str) -> Result<(), Error> {
    write_field(writer, builder, true)?;
    Ok(())
}

pub(crate) fn write_arguments(
    writer: &mut impl Write,
    arguments: &[String],
) -> Result<(), io::Error> {
    write_char(writer, BRACKET_OPEN)?;
    write_array_elements(writer, arguments)?;
    write_char(writer, BRACKET_CLOSE)?;

    Ok(())
}

pub(crate) fn write_environment<E, K, V>(
    writer: &mut impl Write,
    environment: E,
) -> Result<(), io::Error>
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
