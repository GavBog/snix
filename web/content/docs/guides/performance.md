---
title: "Performance"
description: ""
summary: ""
date: 2025-12-19T21:00:35+03:00
lastmod: 2025-12-19T21:00:35+03:00
draft: false
weight: 13
toc: true
---

There's various ways to look at Snix performance, and see where it spends time
(and why). This document describes how to inspect Snix, using various
techniques.

{{< callout context="tip" title="Did you know?" icon="outline/rocket" >}}
There also plenty of few known issues and (low-)hanging fruits.
If you find something, best to check the [issue tracker][issues] - it
might already be a known issue, or there a design proposal on how to solve it.

[issues]: https://git.snix.dev/snix/snix/issues
{{< /callout >}}

## Chrome Trace Event Format
Snix supports emitting traces in Chrome's trace event format that can be viewed
with `chrome://tracing` or [ui.perfetto.dev](https://ui.perfetto.dev).

Compile and run Snix with the `tracing-chrome` feature flag enabled,
and run it with the `--tracer=chrome-style` command line arg.

After stopping the binary, a file named like `trace-1668480819035032.json` will
be written to your current working directory, which you can drag & drop into the
above web interface.

You might need to expand the "Global Legacy Events" section to see the graph.

If you want to compare multiple traces, make sure to have
`dev.perfetto.MultiTraceOpen` enabled (in "Settings" > "Plugins").
If enabled, a new menu item "New Trace" > "Open multiple trace files" should
be available.


## OTLP
Snix comes with [OpenTelemetry][] support [^opentelemetry].
It can be enabled by running Snix with the `--tracer=otlp` command line
argument.
You need to have an OTLP collector running, which will collect these traces.

It will give you "callgraphs" of various Snix components, alongside with
timing information and function arguments, potentially even crossing machine
boundaries (thanks to trace propagation). It is a good tool to understand where
things take time, due to too many round-trips, unnecessary lookups, linearity, …

In a production scenario, you will have these collectors running on all your
machines, and some centralized service ingesting and aggregating all traces,
across your infrastructure.

If you don't have such a thing running, but want to give it a try, you can spin
up a testing one on demand:

```sh
docker run -d --name jaeger \
  -e COLLECTOR_ZIPKIN_HOST_PORT=:9411 \
  -e COLLECTOR_OTLP_ENABLED=true \
  -p 6831:6831/udp \
  -p 6832:6832/udp \
  -p 5778:5778 \
  -p 16686:16686 \
  -p 4317:4317 \
  -p 4318:4318 \
  -p 14250:14250 \
  -p 14268:14268 \
  -p 14269:14269 \
  -p 9411:9411 --rm \
  jaegertracing/all-in-one:1.76.0
```

This starts Jaeger, an OpenTelemetry collector. You will be able to access a web
interface at http://localhost:16686/search.

After running Snix, you should see some spans in the web interface.

As documented in the [OpenTelemetry docs][otlp-docs], you can also
point Snix to push to another location by setting `OTEL_EXPORTER_OTLP_ENDPOINT`.
However note it is recommended to keep the collectors close to where the
binaries are running.

## Tracy
Snix has optional support for [Tracy][], "a real time, nanosecond resolution,
remote telemetry, hybrid frame and sampling profiler for games and other
applications".
Refer to the [Important Information][tracy-important-information] and only
proceed when you understood the implications.

If you compile it with the `tracy` feature flag enabled, and run with the
`--tracer=tracy` command line argument, the process will collect data while
running and wait for the Tracy tool itself to collect the trace.

This can be done by running `tracy -a 127.0.0.1` in a separate Terminal before
running Snix with this feature enabled. If Tracy does not run, Snix will block
indefinitely after termination, waiting for Tracy to pick up the trace.

{{< callout context="caution" title="Caution" icon="outline/alert-triangle" >}}
Unfortunately, while it seems to be a very powerful tool, Tracy doesn't seem to
work too well with the async ecosystem, so it might be of limited in only very
little scenarios.

The `fibers` feature might change this, but we didn't really investigate a lot
so far. Help welcome!
{{</callout>}}

## Benchmarking
### Microbenchmarks
We have a few benchmarks in Rust, using [Criterion.rs][criterion]).

These mostly test parsers for `nix-compat`, as well as various synthetic
scenarios in Nixlang (attrset creation and merging).

They can be reached by running `cargo bench` inside the `snix` workspace.

### Macrobenchmarks
We also have a few Macrobenchmarks, running various Snix binaries to do a longer
task.

These currently mostly evaluate various attrpaths in nixpkgs, and measure the
time. They can be accessed by building the `snix.cli.eval.benchmark-*` attrsets
(in `snix/cli/eval/default.nix`), currently emit a very simple JSON, logging the time
and memory used.

### Continuous Benchmarking

{{< callout context="caution" title="Caution" icon="outline/alert-triangle" >}}
We plan to extend these scenarios, as well as the metrics collected, and ideally
regularly run them in CI to track regressions (and improvements!) over time.

If this is something that piques your interest, reach out - Help welcome!
{{</callout>}}


[^opentelemetry]: It will push to an endpoint running on `localhost`, not anywhere else.

[OpenTelemetry]: https://opentelemetry.io/
[otlp-docs]: https://docs.rs/opentelemetry-otlp/latest/opentelemetry_otlp/
[Tracy]: https://github.com/wolfpld/tracy
[tracy-important-information]: https://docs.rs/tracing-tracy/latest/tracing_tracy/#important-note
[criterion]: https://github.com/bheisler/criterion.rs
