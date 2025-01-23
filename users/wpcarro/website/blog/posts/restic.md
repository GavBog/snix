Continuing along the trend that [Profpatsch][2] recently inspired in me: writing
short notes to myself instead of fully fledged blog posts aimed at some
unknowable audience. Today we're looking at how I burned myself by only
*partially* RTFD.

## Background

I recently started using [restic][4] and NixOS thanks to the help of [TVL's
`restic.nix` module][1]. I setup `1x/h` backups to [MinIO][3] (S3-compatible
storage) for just a handful of `/var/lib` directories (`~9GiB` total), but after
a few days MinIO reported that my bucket size was `O(100GiB)`!

> What's going on?
> -- me

```shell
$ restic stats
repository 763bfe37 opened successfully, password is correct
scanning...
Stats in restore-size mode:
Snapshots processed:   175
   Total File Count:   31369384
         Total Size:   21.027 GiB
```

> Wait: 20GiB... wat?
> -- me (moments later)

Maybe we're snapshotting our MinIO buckets, and that's contributing to our
bucket size. Checking the logs proved that `restic` was backing-up `1.5GiB/h`,
which supported MinIO's reports.

> Ah maybe `restic stats` isn't reporting what I *think* it's reporting...
> -- me (again)

Let's consult Le Docs:

```shell
$ restic stats -h

The "stats" command walks one or multiple snapshots in a repository
and accumulates statistics about the data stored therein. It reports
on the number of unique files and their sizes, according to one of
the counting modes as given by the --mode flag.

It operates on all snapshots matching the selection criteria or all
snapshots if nothing is specified. The special snapshot ID "latest"
is also supported. Some modes make more sense over
just a single snapshot, while others are useful across all snapshots,
depending on what you are trying to calculate.

[to be continued]
```

This is where I stopped reading (the first time). But then I returned a second
time as I was running low on theories...

```shell
[continued]

The modes are:

* restore-size: (default) Counts the size of the restored files.
* files-by-contents: Counts total size of files, where a file is
   considered unique if it has unique contents.
* raw-data: Counts the size of blobs in the repository, regardless of
  how many files reference them.
* blobs-per-file: A combination of files-by-contents and raw-data.
```

Bingo: `--mode=raw-data` **not** `--mode=restore-size`.

## Solution

```shell
$ restic stats --mode=raw-data
repository 763bfe37 opened successfully, password is correct
scanning...
Stats in raw-data mode:
Snapshots processed:   175
   Total Blob Count:   710988
         Total Size:   303.216 GiB
```

> Ah... the world agrees again.
> -- me

[1]: https://code.tvl.fyi/blob/ops/modules/restic.nix?id=2ec0d3611960b163a7052e8554ba065f3c89a8cc#n9
[2]: https://github.com/profpatsch
[3]: https://min.io/
[4]: https://restic.net/
