# fetchroots

> This tool is part of a suite of tools built to manage cache.nixos.org.

This tool's purpose is to build an index of all the GC roots from the
channels.nixos.org releases. The result is then combined with other tools.

It does this by:
1. Listing all the release files in the bucket.
2. Getting the data for each of the release.
3. Putting them in a local parquet file.

## Getting started

In order to run this, you'll need AWS SSO credentials from the NixOS Infra team.

Get the creds from https://nixos.awsapps.com/start/ -> LBNixOS_Dev_PDX -> AWSReadOnlyAccess.

Run `mg run`, you should see a progress bar.

Congrats, you now have a `roots.parquet` file. You can now load it with python polars-rs or clickhouse.

## `roots.parquet` file format

 * `key` (`String`): the release, eg `nixos/22.11-small/nixos-22.11.513.563dc6476b8`
 * `timestamp` (`DateTime`): the timestamp of the GC roots file for this release
 * `store_path_hash` (`List[Binary]`): hash part of the store paths rooted by this release

## Development

When the Cargo.lock changes, run `mg run //tools:crate2nix-generate`.

To build the project, run `mg build`.

To get a dev environment, run `nix-shell -p cargo`.

