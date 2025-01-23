mq-cli
======

This project provides a very simple CLI interface to [POSIX message queues][].

It can be used to create and inspect queues, as well as send and
receive messages from them.

```
1.0.0
Administrate and inspect POSIX message queues

USAGE:
    mq <SUBCOMMAND>

FLAGS:
    -h, --help       Prints help information
    -V, --version    Prints version information

SUBCOMMANDS:
    create     Create a new queue
    help       Prints this message or the help of the given subcommand(s)
    inspect    inspect details about a queue
    ls         list message queues
    receive    Receive a message from a queue
    rlimit     Get the message queue rlimit
    send       Send a message to a queue
```

## Development

Development happens in the [TVL
monorepo](https://code.tvl.fyi/tree/ops/mq_cli).

Starting from version `3773.0.0`, the version numbers correspond to
_revisions_ of the TVL repository, available as git refs (e.g.
`refs/r/3773`).

See the TVL documentation for more information about how to contribute
to the codebase.

[POSIX message queues]: https://linux.die.net/man/7/mq_overview
