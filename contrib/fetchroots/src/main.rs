//! Fetch all[^1] GC roots from releases.nixos.org into a `roots.parquet` file.
//!
//! The resulting Parquet has three columns:
//!
//!  * `key` (`String`): the release, eg `nixos/22.11-small/nixos-22.11.513.563dc6476b8`
//!  * `git_rev` (`Binary`): the git revision hash of this release, if available
//!  * `timestamp` (`DateTime`): the timestamp of the GC roots file for this release
//!  * `store_path_hash` (`List[Binary]`): hash part of the store paths rooted by this release
//!
//! [^1]: some roots are truly ancient, and aren't compatible with Nix 1.x

use anyhow::Result;
use data_encoding::HEXLOWER;
use std::{
    collections::BTreeMap,
    fs::File,
    io::{BufRead, Read},
    sync::Arc,
    time::SystemTime,
};

use aws_config::Region;
use aws_sdk_s3::operation::get_object::builders::GetObjectFluentBuilder;
use bytes::{Buf, Bytes};
use bytes_utils::SegmentedBuf;
use chrono::{DateTime, Utc};
use nix_compat::nixbase32;
use polars::prelude::*;
use tokio::{
    sync::Semaphore,
    task::{JoinSet, block_in_place},
};

#[derive(Debug)]
struct Meta {
    format: Format,
    e_tag: String,
    last_modified: DateTime<Utc>,
}

#[tokio::main]
#[allow(clippy::too_many_lines)]
async fn main() {
    let sdk_config = aws_config::load_defaults(aws_config::BehaviorVersion::v2023_11_09())
        .await
        .into_builder()
        .region(Region::from_static("eu-west-1"))
        .build();

    let s3 = aws_sdk_s3::Client::new(&sdk_config);

    let mut keys: BTreeMap<String, Meta> = {
        let pages = s3
            .list_objects_v2()
            .bucket("nix-releases")
            .into_paginator()
            .send()
            .try_collect()
            .await
            .unwrap();

        let objects = pages.into_iter().flat_map(|page| {
            assert_eq!(page.prefix().unwrap_or_default(), "");
            assert!(page.common_prefixes.is_none());
            page.contents.unwrap_or_default()
        });

        let mut prev_key = String::new();
        objects
            .filter_map(|obj| {
                let key = obj.key().unwrap();

                assert!(&*prev_key < key);
                key.clone_into(&mut prev_key);

                let (key, tail) = key.rsplit_once('/')?;
                // Our preference order happens to match lexicographical order,
                // and listings are returned in lexicographical order.
                let format = match tail {
                    "MANIFEST" => Format::Manifest,
                    "MANIFEST.bz2" => Format::ManifestBz,
                    "store-paths.xz" => Format::StorePathsXz,
                    _ => return None,
                };

                Some((
                    key.to_owned(),
                    Meta {
                        format,
                        e_tag: obj.e_tag.unwrap(),
                        last_modified: SystemTime::try_from(obj.last_modified.unwrap())
                            .unwrap()
                            .into(),
                    },
                ))
            })
            .collect()
    };

    // These releases are so old they don't even use nixbase32 store paths.
    for key in [
        "nix/nix-0.6",
        "nix/nix-0.6.1",
        "nix/nix-0.7",
        "nix/nix-0.8",
        "nixpkgs/nixpkgs-0.5",
        "nixpkgs/nixpkgs-0.5.1",
        "nixpkgs/nixpkgs-0.6",
        "nixpkgs/nixpkgs-0.7",
        "nixpkgs/nixpkgs-0.8",
        "nixpkgs/nixpkgs-0.9",
        "nixpkgs/nixpkgs-0.10",
        "nixpkgs/nixpkgs-0.11",
    ] {
        assert!(keys.remove(key).is_some());
    }

    let mut js = JoinSet::new();
    let sem = Arc::new(Semaphore::new(16));

    let bar = indicatif::ProgressBar::new(keys.len() as u64);
    for (root, meta) in keys {
        let sem = sem.clone();
        let s3 = s3.clone();

        js.spawn(async move {
            let _permit = sem.acquire().await.unwrap();

            // TODO(edef): learn whether there is a git-revision from the listings
            let rev = s3
                .get_object()
                .bucket("nix-releases")
                .key(format!("{root}/git-revision"))
                .send()
                .await;

            let rev = match rev {
                Ok(resp) => {
                    let hex = resp.body.collect().await.unwrap().to_vec();
                    let mut buf = [0; 20];
                    assert_eq!(HEXLOWER.decode_mut(&hex, &mut buf).unwrap(), buf.len());
                    Ok(Some(buf))
                }
                Err(e) => {
                    if e.as_service_error().is_some_and(
                        aws_sdk_s3::operation::get_object::GetObjectError::is_no_such_key,
                    ) {
                        Ok(None)
                    } else {
                        Err(e)
                    }
                }
            }
            .unwrap();

            let body = get_object(
                s3.get_object()
                    .bucket("nix-releases")
                    .key(format!("{root}/{}", meta.format.as_str()))
                    .if_match(meta.e_tag),
            )
            .await
            .unwrap()
            .reader();

            let ph_array = block_in_place(|| meta.format.to_ph_array(body).rechunk());
            df! {
                "key" => [root],
                "git_rev" => [rev.as_ref().map(|r| &r[..])],
                "timestamp" => [meta.last_modified.naive_utc()],
                "store_path_hash" => ph_array.into_series().implode().unwrap()
            }
            .unwrap()
        });
    }

    let mut writer = ParquetWriter::new(File::create("roots.parquet").unwrap())
        .batched(&Schema::from_iter([
            Field::new("key", DataType::String),
            Field::new("git_rev", DataType::Binary),
            Field::new(
                "timestamp",
                DataType::Datetime(TimeUnit::Milliseconds, None),
            ),
            Field::new(
                "store_path_hash",
                DataType::List(Box::new(DataType::Binary)),
            ),
        ]))
        .unwrap();

    while let Some(df) = js.join_next().await.transpose().unwrap() {
        block_in_place(|| writer.write_batch(&df)).unwrap();
        bar.inc(1);
    }

    writer.finish().unwrap();
}

#[derive(Debug)]
enum Format {
    Manifest,
    ManifestBz,
    StorePathsXz,
}

impl Format {
    fn as_str(&self) -> &'static str {
        match self {
            Format::Manifest => "MANIFEST",
            Format::ManifestBz => "MANIFEST.bz2",
            Format::StorePathsXz => "store-paths.xz",
        }
    }

    fn to_ph_array(&self, mut body: impl BufRead) -> BinaryChunked {
        match self {
            Format::Manifest | Format::ManifestBz => {
                let mut buf = String::new();
                match self {
                    Format::Manifest => {
                        body.read_to_string(&mut buf).unwrap();
                    }
                    Format::ManifestBz => {
                        bzip2::bufread::BzDecoder::new(body)
                            .read_to_string(&mut buf)
                            .unwrap();
                    }
                    Format::StorePathsXz => unreachable!(),
                }

                let buf = buf
                    .strip_prefix("version {\n  ManifestVersion: 3\n}\n")
                    .unwrap();

                BinaryChunked::from_iter_values(
                    "store_path_hash",
                    buf.split_terminator("}\n").map(|chunk| -> [u8; 20] {
                        let chunk = chunk.strip_prefix("patch ").unwrap_or(chunk);
                        let line = chunk.strip_prefix("{\n  StorePath: /nix/store/").unwrap();
                        nixbase32::decode_fixed(&line[..32]).unwrap()
                    }),
                )
            }
            Format::StorePathsXz => {
                let mut buf = String::new();
                xz2::bufread::XzDecoder::new(body)
                    .read_to_string(&mut buf)
                    .unwrap();

                BinaryChunked::from_iter_values(
                    "store_path_hash",
                    buf.split_terminator('\n').map(|line| -> [u8; 20] {
                        let line = line.strip_prefix("/nix/store/").unwrap();
                        nixbase32::decode_fixed(&line[..32]).unwrap()
                    }),
                )
            }
        }
    }
}

async fn get_object(request: GetObjectFluentBuilder) -> Result<SegmentedBuf<Bytes>> {
    // if we don't constrain the ETag, we might experience read skew
    assert!(request.get_if_match().is_some(), "if_match must be set");

    let mut buf: SegmentedBuf<Bytes> = SegmentedBuf::new();
    let mut resp = request.clone().send().await?;
    let content_length: usize = resp.content_length.unwrap().try_into().unwrap();

    loop {
        while let Ok(Some(chunk)) = resp.body.try_next().await {
            buf.push(chunk);
        }

        if buf.remaining() >= content_length {
            assert_eq!(buf.remaining(), content_length, "got excess bytes");
            break Ok(buf);
        }

        resp = request
            .clone()
            .range(format!("bytes={}-", buf.remaining()))
            .send()
            .await?;

        assert_ne!(resp.content_range, None);
    }
}
