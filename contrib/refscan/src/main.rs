// SPDX-FileCopyrightText: edef <edef@edef.eu>
// SPDX-License-Identifier: MPL-2.0

use std::{
    collections::BTreeSet as Set,
    convert::TryInto,
    io::{self, Read},
    str,
};

fn main() {
    let max_refs: Set<[u8; 32]> = include_str!("../testdata/maxrefs")
        .lines()
        .map(|l| l.as_bytes().try_into().unwrap())
        .collect();

    let input = {
        let stdin = io::stdin();
        let mut buffer = Vec::new();
        stdin.lock().read_to_end(&mut buffer).unwrap();
        buffer
    };

    let base = input.as_ptr() as usize;
    let mut input: &[u8] = &input;
    while input.len() >= 32 {
        match refscan::scan_clean(&input) {
            Ok(buffer) | Err(buffer) => {
                let n = buffer.len();
                input = &input[n..];
            }
        }

        let buffer = {
            let idx = input.iter().position(|x| match x {
                b'a'..=b'z' | b'0'..=b'9' => false,
                _ => true,
            });
            idx.map(|idx| &input[..idx]).unwrap_or(input)
        };

        for chunk in buffer.windows(32) {
            let offset = (chunk.as_ptr() as usize) - base;
            let chunk = {
                let mut fixed = [0u8; 32];
                fixed.copy_from_slice(chunk);
                fixed
            };
            if max_refs.contains(&chunk) {
                let seen = unsafe { str::from_utf8_unchecked(&chunk) };
                println!("{} {}", seen, offset);
            }
        }

        let n = buffer.len();
        input = &input[n..];
    }
}
