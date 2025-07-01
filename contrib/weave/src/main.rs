//! Weave resolves a list of roots from `releases.parquet` against `narinfo.parquet`,
//! and then uses the reference graph from the accompanying `narinfo-references.parquet`
//! produced by `swizzle` to collect the closure of the roots.
//!
//! They are written to `live_idxs.parquet`, which only has one column, representing
//! the row numbers in `narinfo.parquet` corresponding to live paths.

use anyhow::Result;
use hashbrown::{HashTable, hash_table};
use rayon::prelude::*;
use rustc_hash::FxHashSet;
use std::{
    collections::BTreeMap,
    fs::File,
    ops::Index,
    sync::atomic::{AtomicU32, Ordering},
};
use tracing::{info_span, warn};
use tracing_indicatif::span_ext::IndicatifSpanExt;

use polars::{
    datatypes::StaticArray,
    export::arrow::{array::UInt32Array, offset::OffsetsBuffer},
    lazy::dsl::col,
    prelude::*,
};

use weave::{INDEX_NULL, as_fixed_binary, hash64};

#[tracing::instrument]
fn main() -> Result<()> {
    let _tracing = snix_tracing::TracingBuilder::default()
        .enable_progressbar()
        .build()?;

    let roots: PathSet32 = {
        let span = info_span!("parse_roots", indicatif.pb_show = tracing::field::Empty).entered();
        span.pb_set_message("parse roots");
        span.pb_start();

        as_fixed_binary::<20>(
            LazyFrame::scan_parquet("releases.parquet", ScanArgsParquet::default())?
                .explode([col("store_path_hash")])
                .select([col("store_path_hash")])
                .collect()?
                .column("store_path_hash")?
                .binary()?,
        )
        .flatten()
        .collect()
    };

    {
        let span = info_span!("resolve_roots", indicatif.pb_show = tracing::field::Empty).entered();
        span.pb_set_message("resolve roots");
        span.pb_start();

        weave::load_ph_array()?
            .into_par_iter()
            .enumerate()
            .for_each(|(idx, h)| {
                if let Some(idx_slot) = roots.find(h) {
                    assert_eq!(
                        idx_slot.swap(idx as u32, Ordering::Relaxed),
                        INDEX_NULL,
                        "duplicate entry"
                    );
                }
            });
    }

    let mut todo = FxHashSet::default();
    todo.reserve(roots.len());
    {
        let mut unknown_roots = 0usize;
        for (_, idx) in roots.table {
            let idx = idx.into_inner();
            if idx == INDEX_NULL {
                unknown_roots += 1;
                continue;
            }
            todo.insert(idx);
        }

        if unknown_roots != 0 {
            warn!("skipping {unknown_roots} unknown roots");
        }
    }

    let ri_array;
    let ri_array = {
        let span = info_span!(
            "load_reference_idxs",
            indicatif.pb_show = tracing::field::Empty
        )
        .entered();
        span.pb_set_message("load reference_idxs");
        span.pb_start();

        ri_array = ParquetReader::new(File::open("narinfo-references.parquet")?)
            .finish()?
            .column("reference_idxs")?
            .list()?
            .clone();

        ChunkedList::new(ri_array.downcast_iter().map(|chunk| {
            (
                chunk.offsets(),
                chunk
                    .values()
                    .as_any()
                    .downcast_ref::<UInt32Array>()
                    .unwrap()
                    .as_slice()
                    .unwrap(),
            )
        }))
    };

    let mut seen = todo.clone();
    {
        let span = info_span!("mark", indicatif.pb_show = tracing::field::Empty).entered();
        span.pb_set_message("marking");
        span.pb_set_style(&snix_tracing::PB_PROGRESS_STYLE);

        while !todo.is_empty() {
            span.pb_set_length(seen.len() as u64);
            span.pb_set_position(seen.len().saturating_sub(todo.len()) as u64);

            todo = todo
                .par_iter()
                .flat_map(|&parent| {
                    if parent == INDEX_NULL {
                        return FxHashSet::default();
                    }

                    ri_array[parent as usize]
                        .iter()
                        .cloned()
                        .filter(|child| !seen.contains(child))
                        .collect::<FxHashSet<u32>>()
                })
                .collect();

            for &index in &todo {
                seen.insert(index);
            }
        }

        span.pb_set_length(seen.len() as u64);
        span.pb_set_position(seen.len() as u64);

        if seen.remove(&INDEX_NULL) {
            warn!("WARNING: missing edges");
        }
    }

    let seen = {
        let span = info_span!("gather_live", indicatif.pb_show = tracing::field::Empty).entered();
        span.pb_set_message("gathering live set");

        let mut seen: Vec<u32> = seen.into_iter().collect();
        seen.par_sort();
        seen
    };

    {
        let span = info_span!("write_output", indicatif.pb_show = tracing::field::Empty).entered();
        span.pb_set_message("writing output");
        span.pb_start();

        ParquetWriter::new(File::create("live_idxs.parquet")?).finish(&mut df! {
            "live_idx" => seen,
        }?)?;
    }

    Ok(())
}

struct PathSet32 {
    table: HashTable<([u8; 20], AtomicU32)>,
}

impl PathSet32 {
    fn with_capacity(capacity: usize) -> Self {
        Self {
            table: HashTable::with_capacity(capacity),
        }
    }

    fn insert(&mut self, value: &[u8; 20]) -> bool {
        let hash = hash64(value);

        match self
            .table
            .entry(hash, |(x, _)| x == value, |(x, _)| hash64(x))
        {
            hash_table::Entry::Occupied(_) => false,
            hash_table::Entry::Vacant(entry) => {
                entry.insert((*value, AtomicU32::new(INDEX_NULL)));
                true
            }
        }
    }

    fn find(&self, value: &[u8; 20]) -> Option<&AtomicU32> {
        let hash = hash64(value);
        self.table
            .find(hash, |(x, _)| x == value)
            .as_ref()
            .map(|(_, x)| x)
    }

    fn len(&self) -> usize {
        self.table.len()
    }
}

impl<'a> FromIterator<&'a [u8; 20]> for PathSet32 {
    fn from_iter<T: IntoIterator<Item = &'a [u8; 20]>>(iter: T) -> Self {
        let iter = iter.into_iter();
        let mut this = Self::with_capacity(iter.size_hint().0);

        for item in iter {
            this.insert(item);
        }

        this.table.shrink_to_fit(|(x, _)| hash64(x));
        this
    }
}

struct ChunkedList<'a, T> {
    by_offset: BTreeMap<usize, (&'a OffsetsBuffer<i64>, &'a [T])>,
}

impl<'a, T> ChunkedList<'a, T> {
    fn new(chunks: impl IntoIterator<Item = (&'a OffsetsBuffer<i64>, &'a [T])>) -> Self {
        let mut next_offset = 0usize;
        ChunkedList {
            by_offset: chunks
                .into_iter()
                .map(|(offsets, values)| {
                    let offset = next_offset;
                    next_offset = next_offset.checked_add(offsets.len_proxy()).unwrap();

                    (offset, (offsets, values))
                })
                .collect(),
        }
    }
}

impl<'a, T> Index<usize> for ChunkedList<'a, T> {
    type Output = [T];

    fn index(&self, index: usize) -> &Self::Output {
        let (&base, &(offsets, values)) = self.by_offset.range(..=index).next_back().unwrap();
        let (start, end) = offsets.start_end(index - base);
        &values[start..end]
    }
}
