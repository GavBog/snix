use anyhow::Result;
use owning_ref::{ArcRef, OwningRef};
use rayon::prelude::*;
use std::{
    fs::File,
    mem,
    ops::{Deref, Range},
    slice,
    sync::Arc,
};
use tracing_indicatif::span_ext::IndicatifSpanExt as _;

use polars::{
    datatypes::BinaryChunked,
    export::arrow::array::BinaryArray,
    prelude::{ParquetReader, SerReader},
};

/// An shared `[[u8; N]]` backed by a Polars [Buffer].
pub type FixedBytes<const N: usize> =
    ArcRef<'static, polars::export::arrow::buffer::Bytes<u8>, [[u8; N]]>;

pub const INDEX_NULL: u32 = !0;

/// A terrific hash function, turning 20 bytes of cryptographic hash
/// into 8 bytes of cryptographic hash.
pub fn hash64(h: &[u8; 20]) -> u64 {
    let mut buf = [0; 8];
    buf.copy_from_slice(&h[..8]);
    u64::from_ne_bytes(buf)
}

pub fn leak<O, T: ?Sized>(r: OwningRef<Arc<O>, T>) -> &T {
    // SAFETY: Either `ptr` points into the `Arc`, which lives until `r` is dropped,
    // or it points at something else entirely which lives at least as long.
    unsafe {
        let ptr: *const T = r.deref();
        mem::forget(r);
        &*ptr
    }
}

/// Read a dense `store_path_hash` array from `narinfo.parquet`,
/// returning it as an owned [FixedBytes].
#[tracing::instrument(fields(indicatif.pb_show = tracing::field::Empty))]
pub fn load_ph_array() -> Result<FixedBytes<20>> {
    let span = tracing::Span::current();

    span.pb_set_message("load store_path_hash");
    span.pb_start();

    // TODO(edef): this could use a further pushdown, since polars is more hindrance than help here
    // We know this has to fit in memory (we can't mmap it without further encoding constraints),
    // and we want a single `Vec<[u8; 20]>` of the data.
    let ph_array = into_fixed_binary_rechunk::<20>(
        ParquetReader::new(File::open("narinfo.parquet").unwrap())
            .with_columns(Some(vec!["store_path_hash".into()]))
            .set_rechunk(true)
            .finish()?
            .column("store_path_hash")?
            .binary()?,
    );

    u32::try_from(ph_array.len()).expect("dataset exceeds 2^32");

    Ok(ph_array)
}

/// Iterator over `&[[u8; N]]` from a dense [BinaryChunked].
pub fn as_fixed_binary<const N: usize>(
    chunked: &BinaryChunked,
) -> impl DoubleEndedIterator<Item = &[[u8; N]]> {
    chunked.downcast_iter().map(|array| {
        let range = assert_fixed_dense::<N>(array);
        exact_chunks(&array.values()[range]).unwrap()
    })
}

/// Convert a dense [BinaryChunked] into a single chunk as [FixedBytes],
/// without taking a reference to the offsets array and validity bitmap.
fn into_fixed_binary_rechunk<const N: usize>(chunked: &BinaryChunked) -> FixedBytes<N> {
    let chunked = chunked.rechunk();
    let mut iter = chunked.downcast_iter();
    let array = iter.next().unwrap();
    assert!(iter.next().is_none());

    let (buf, off, len) = {
        let range = assert_fixed_dense::<N>(array);
        array.values().clone().sliced(range.start, range.len())
    }
    .into_inner();

    ArcRef::new(buf).map(|bytes| exact_chunks(&bytes[off..off + len]).unwrap())
}

/// Ensures that the supplied Arrow array consists of densely packed bytestrings of length `N`.
/// In other words, ensure that it is free of nulls, and that the offsets have a fixed stride of `N`.
#[must_use = "only the range returned is guaranteed to be conformant"]
fn assert_fixed_dense<const N: usize>(array: &BinaryArray<i64>) -> Range<usize> {
    let null_count = array.validity().map_or(0, |bits| bits.unset_bits());
    if null_count > 0 {
        panic!("null values present");
    }

    let offsets = array.offsets();
    let length_check = offsets
        .as_slice()
        .par_windows(2)
        .all(|w| (w[1] - w[0]) == N as i64);

    if !length_check {
        panic!("lengths are inconsistent");
    }

    (*offsets.first() as usize)..(*offsets.last() as usize)
}

fn exact_chunks<const K: usize>(buf: &[u8]) -> Option<&[[u8; K]]> {
    // SAFETY: We ensure that `buf.len()` is a multiple of K, and there are no alignment requirements.
    unsafe {
        let ptr = buf.as_ptr();
        let len = buf.len();

        if len % K != 0 {
            return None;
        }

        let ptr = ptr as *mut [u8; K];
        let len = len / K;

        Some(slice::from_raw_parts(ptr, len))
    }
}
