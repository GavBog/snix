#![cfg_attr(docsrs, feature(doc_cfg))]

#[cfg(feature = "clap")]
use clap_verbosity_flag::{InfoLevel, LogLevel, Verbosity};
#[cfg(any(feature = "otlp", feature = "tracy", feature = "chrome"))]
use enumset::EnumSet;
use std::sync::LazyLock;
use tracing::{Level, debug, level_filters::LevelFilter};
use tracing_indicatif::{
    IndicatifLayer, IndicatifWriter, filter::IndicatifFilter, style::ProgressStyle,
    util::FilteredFormatFields, writer,
};
use tracing_subscriber::{
    EnvFilter, Layer, Registry,
    layer::{Identity, SubscriberExt},
    util::SubscriberInitExt as _,
};

#[cfg(feature = "otlp")]
use opentelemetry_sdk::{
    Resource, propagation::TraceContextPropagator, resource::SdkProvidedResourceDetector,
};
#[cfg(feature = "tracy")]
use tracing_tracy::TracyLayer;

pub mod propagate;

pub static PB_PROGRESS_STYLE: LazyLock<ProgressStyle> = LazyLock::new(|| {
    ProgressStyle::with_template(
        "{span_child_prefix} {wide_msg} {bar:10} ({elapsed}) {pos:>7}/{len:7}",
    )
    .expect("invalid progress template")
});
pub static PB_TRANSFER_STYLE: LazyLock<ProgressStyle> = LazyLock::new(|| {
    ProgressStyle::with_template(
        "{span_child_prefix} {wide_msg} {binary_bytes:>7}/{binary_total_bytes:7}@{decimal_bytes_per_sec} ({elapsed}) {bar:10} "
    )
    .expect("invalid progress template")
});
pub static PB_SPINNER_STYLE: LazyLock<ProgressStyle> = LazyLock::new(|| {
    ProgressStyle::with_template(
        "{span_child_prefix}{spinner} {wide_msg} ({elapsed}) {pos:>7}/{len:7}",
    )
    .expect("invalid progress template")
});

#[derive(thiserror::Error, Debug)]
pub enum Error {
    #[error(transparent)]
    Init(#[from] tracing_subscriber::util::TryInitError),

    #[cfg(feature = "otlp")]
    #[error(transparent)]
    OTEL(#[from] opentelemetry_sdk::error::OTelSdkError),
}

#[derive(Clone)]
pub struct TracingHandle {
    stdout_writer: IndicatifWriter<writer::Stdout>,
    stderr_writer: IndicatifWriter<writer::Stderr>,

    #[cfg(feature = "chrome")]
    #[allow(dead_code)]
    chrome_guard: Option<std::rc::Rc<tracing_chrome::FlushGuard>>,

    #[cfg(feature = "otlp")]
    meter_provider: Option<opentelemetry_sdk::metrics::SdkMeterProvider>,

    #[cfg(feature = "otlp")]
    tracer_provider: Option<opentelemetry_sdk::trace::SdkTracerProvider>,
}

impl TracingHandle {
    /// Returns a writer for [std::io::Stdout] that ensures its output will not be clobbered by
    /// active progress bars.
    ///
    /// Instead of `println!(...)` prefer `writeln!(handle.get_stdout_writer(), ...)`
    pub fn get_stdout_writer(&self) -> IndicatifWriter<writer::Stdout> {
        // clone is fine here because its only a wrapper over an `Arc`
        self.stdout_writer.clone()
    }

    /// Returns a writer for [std::io::Stderr] that ensures its output will not be clobbered by
    /// active progress bars.
    ///
    /// Instead of `println!(...)` prefer `writeln!(handle.get_stderr_writer(), ...)`.
    pub fn get_stderr_writer(&self) -> IndicatifWriter<writer::Stderr> {
        // clone is fine here because its only a wrapper over an `Arc`
        self.stderr_writer.clone()
    }

    /// This will flush possible attached tracing providers, e.g. otlp exported, if enabled.
    /// If there is none enabled this will result in a noop.
    ///
    /// It will wait until the flush is complete.
    pub async fn flush(&self) -> Result<(), Error> {
        #[cfg(feature = "otlp")]
        {
            if let Some(tracer_provider) = &self.tracer_provider {
                tracer_provider.force_flush()?;
            }
            if let Some(meter_provider) = &self.meter_provider {
                meter_provider.force_flush()?;
            }
        }
        Ok(())
    }

    /// This will flush all attached tracing providers and will wait until the flush is completed, then call shutdown.
    /// If no tracing providers like otlp are attached then this will be a noop.
    ///
    /// This should only be called on a regular shutdown.
    pub async fn shutdown(&self) -> Result<(), Error> {
        self.flush().await?;
        #[cfg(feature = "otlp")]
        {
            if let Some(tracer_provider) = &self.tracer_provider {
                tracer_provider.shutdown()?;
            }
            if let Some(meter_provider) = &self.meter_provider {
                meter_provider.shutdown()?;
            }
        }

        Ok(())
    }
}

#[cfg(any(feature = "otlp", feature = "tracy", feature = "chrome"))]
#[derive(enumset::EnumSetType, Debug)]
#[cfg_attr(feature = "clap", derive(clap::ValueEnum))]
pub enum Tracer {
    #[cfg(feature = "otlp")]
    Otlp,
    #[cfg(feature = "tracy")]
    Tracy,
    #[cfg(feature = "chrome")]
    ChromeStyle,
}

#[must_use = "Don't forget to call build() to enable tracing."]
#[derive(Default)]
pub struct TracingBuilder {
    progess_bar: bool,

    #[cfg(any(feature = "otlp", feature = "tracy", feature = "chrome"))]
    tracers: EnumSet<Tracer>,

    quiet: bool,
    verbosity: Option<Level>,
}

impl TracingBuilder {
    #[cfg(any(feature = "otlp", feature = "tracy", feature = "chrome"))]
    /// Enable the given tracer
    pub fn enable_tracer(mut self, tracer: Tracer) -> TracingBuilder {
        self.tracers.insert(tracer);
        self
    }

    #[cfg(any(feature = "otlp", feature = "tracy", feature = "chrome"))]
    /// Enable the given tracers
    pub fn enable_tracers<I>(mut self, tracers: I) -> TracingBuilder
    where
        I: IntoIterator<Item = Tracer>,
    {
        self.tracers.extend(tracers);
        self
    }

    /// Enable progress bar layer, default is disabled
    pub fn enable_progressbar(mut self) -> TracingBuilder {
        self.progess_bar = true;
        self
    }

    /// Supress log and progress bar output to stderr
    pub fn quiet_output(mut self) -> TracingBuilder {
        self.quiet = true;
        self
    }

    /// Sets the verbosity level, default is INFO
    pub fn with_max_level(mut self, level: Level) -> TracingBuilder {
        self.verbosity = Some(level);
        self
    }

    /// This will setup tracing based on the configuration passed in.
    /// It will setup a stderr writer output layer and configure EnvFilter to honor RUST_LOG.
    /// The EnvFilter will be applied to all configured layers, also otlp.
    ///
    /// It will also configure otlp if the feature is enabled and a service_name was provided. It
    /// will then correctly setup a channel which is later used for flushing the provider.
    pub fn build(self) -> Result<TracingHandle, Error> {
        self.build_with_additional(Identity::new())
    }

    /// Similar to `build()` but allows passing in an additional tracing [`Layer`].
    ///
    /// This method is generic over the `Layer` to avoid the runtime cost of dynamic dispatch.
    /// While it only allows passing a single `Layer`, it can be composed of multiple ones:
    ///
    /// ```ignore
    /// build_with_additional(
    ///   fmt::layer()
    ///     .and_then(some_other_layer)
    ///     .and_then(yet_another_layer)
    ///     .with_filter(my_filter)
    /// )
    /// ```
    /// [`Layer`]: tracing_subscriber::layer::Layer
    pub fn build_with_additional<L>(self, additional_layer: L) -> Result<TracingHandle, Error>
    where
        L: Layer<Registry> + Send + Sync + 'static,
    {
        // Set up the tracing subscriber.
        let indicatif_layer = IndicatifLayer::new().with_progress_style(PB_SPINNER_STYLE.clone());
        let stdout_writer = indicatif_layer.get_stdout_writer();
        let stderr_writer = indicatif_layer.get_stderr_writer();

        let layered = if !self.quiet {
            Some(
                tracing_subscriber::fmt::Layer::new()
                    .fmt_fields(FilteredFormatFields::new(
                        tracing_subscriber::fmt::format::DefaultFields::new(),
                        |field| field.name() != "indicatif.pb_show",
                    ))
                    .with_writer(indicatif_layer.get_stderr_writer())
                    .compact()
                    .and_then((self.progess_bar).then(|| {
                        indicatif_layer.with_filter(
                            // only show progress for spans with indicatif.pb_show field being set
                            IndicatifFilter::new(false),
                        )
                    })),
            )
        } else {
            None
        };
        #[cfg(feature = "chrome")]
        let (layered, chrome_guard) = if self.tracers.contains(Tracer::ChromeStyle) {
            let (chrome_layer, guard) = tracing_chrome::ChromeLayerBuilder::new()
                .include_args(true)
                .trace_style(tracing_chrome::TraceStyle::Async)
                .build();
            (
                Layer::and_then(layered, Some(chrome_layer)),
                Some(std::rc::Rc::new(guard)),
            )
        } else {
            (Layer::and_then(layered, None), None)
        };

        #[cfg(feature = "otlp")]
        let mut g_tracer_provider = None;
        #[cfg(feature = "otlp")]
        let mut g_meter_provider = None;

        // Setup otlp if a service_name is configured
        #[cfg(feature = "otlp")]
        let layered = Layer::and_then(layered, {
            self.tracers.contains(Tracer::Otlp).then(|| {
                use opentelemetry::trace::TracerProvider;

                // register a text map propagator for trace propagation
                opentelemetry::global::set_text_map_propagator(TraceContextPropagator::new());

                let tracer_provider =
                    gen_tracer_provider().expect("Unable to configure trace provider");

                let meter_provider =
                    gen_meter_provider().expect("Unable to configure meter provider");

                // Register the returned meter provider as the global one.
                // FUTUREWORK: store in the struct and provide getter too?
                opentelemetry::global::set_meter_provider(meter_provider.clone());

                g_tracer_provider = Some(tracer_provider.clone());
                g_meter_provider = Some(meter_provider);

                // Create a tracing layer with the configured tracer
                tracing_opentelemetry::layer().with_tracer(tracer_provider.tracer("snix"))
            })
        });

        #[cfg(feature = "tracy")]
        let layered = Layer::and_then(
            layered,
            self.tracers
                .contains(Tracer::Tracy)
                .then(TracyLayer::default),
        );

        let layered = layered.with_filter({
            let b = EnvFilter::builder()
                .with_default_directive(LevelFilter::INFO.into())
                .from_env()
                .expect("invalid RUST_LOG");
            if let Some(level) = self.verbosity {
                b.add_directive(level.into())
            } else {
                b
            }
        });

        tracing_subscriber::registry()
            // TODO: if additional_layer has global filters, there is a risk that it will disable the "default" ones,
            // while it could be solved by registering `additional_layer` last, it requires boxing `additional_layer`.
            .with(additional_layer)
            .with(layered)
            .try_init()?;

        Ok(TracingHandle {
            stdout_writer,
            stderr_writer,

            #[cfg(feature = "otlp")]
            meter_provider: g_meter_provider,
            #[cfg(feature = "otlp")]
            tracer_provider: g_tracer_provider,
            #[cfg(feature = "chrome")]
            chrome_guard,
        })
    }

    #[cfg(feature = "clap")]
    /// Configure with verbosity flags.
    pub fn handle_verbosity_flags<L: LogLevel>(mut self, args: &Verbosity<L>) -> Self {
        if let Some(level) = args.tracing_level() {
            self = self.with_max_level(level)
        } else {
            self = self.quiet_output()
        }

        self
    }

    #[cfg(feature = "clap")]
    /// Configure with the tracing-related args.
    pub fn handle_tracing_args<L: LogLevel>(
        #[allow(unused_mut)] mut self,
        args: &TracingArgs<L>,
    ) -> Self {
        #[cfg(any(feature = "otlp", feature = "tracy", feature = "chrome"))]
        {
            self = self.enable_tracers(args.tracers());
        }
        self.handle_verbosity_flags(&args.verbosity)
    }
}

#[cfg(feature = "otlp")]
fn gen_resources() -> Resource {
    // use SdkProvidedResourceDetector.detect to detect resources.
    Resource::builder()
        .with_detector(Box::new(SdkProvidedResourceDetector))
        .build()
}

/// Returns an OTLP tracer, and the TX part of a channel, which can be used
/// to request flushes (and signal back the completion of the flush).
#[cfg(feature = "otlp")]
fn gen_tracer_provider()
-> Result<opentelemetry_sdk::trace::SdkTracerProvider, opentelemetry::trace::TraceError> {
    use opentelemetry_otlp::{ExportConfig, SpanExporter, WithExportConfig};

    let exporter = SpanExporter::builder()
        .with_tonic()
        .with_export_config(ExportConfig::default())
        .build()?;

    let tracer_provider = opentelemetry_sdk::trace::SdkTracerProvider::builder()
        .with_batch_exporter(exporter)
        .with_resource(gen_resources())
        .build();
    // Unclear how to configure this
    // let batch_config = BatchConfigBuilder::default()
    //     // the default values for `max_export_batch_size` is set to 512, which we will fill
    //     // pretty quickly, which will then result in an export. We want to make sure that
    //     // the export is only done once the schedule is met and not as soon as 512 spans
    //     // are collected.
    //     .with_max_export_batch_size(4096)
    //     // analog to default config `max_export_batch_size * 4`
    //     .with_max_queue_size(4096 * 4)
    //     // only force an export to the otlp collector every 10 seconds to reduce the amount
    //     // of error messages if an otlp collector is not available
    //     .with_scheduled_delay(std::time::Duration::from_secs(10))
    //     .build();

    // use opentelemetry_sdk::trace::BatchSpanProcessor;
    // let batch_span_processor = BatchSpanProcessor::builder(exporter, runtime::Tokio)
    //     .with_batch_config(batch_config)
    //     .build();

    Ok(tracer_provider)
}

// Metric export interval should be less than or equal to 15s
// if the metrics may be converted to Prometheus metrics.
// Prometheus' query engine and compatible implementations
// require ~4 data points / interval for range queries,
// so queries ranging over 1m requre <= 15s scrape intervals.
// OTEL SDKS also respect the env var `OTEL_METRIC_EXPORT_INTERVAL` (no underscore prefix).
const _OTEL_METRIC_EXPORT_INTERVAL: std::time::Duration = std::time::Duration::from_secs(10);

#[cfg(feature = "otlp")]
fn gen_meter_provider()
-> Result<opentelemetry_sdk::metrics::SdkMeterProvider, opentelemetry_sdk::metrics::MetricError> {
    use std::time::Duration;

    use opentelemetry_otlp::WithExportConfig;
    use opentelemetry_sdk::metrics::{PeriodicReader, SdkMeterProvider};
    let exporter = opentelemetry_otlp::MetricExporter::builder()
        .with_tonic()
        .with_timeout(Duration::from_secs(10))
        .build()?;

    let reader = PeriodicReader::builder(exporter)
        .with_interval(_OTEL_METRIC_EXPORT_INTERVAL)
        .build();

    Ok(SdkMeterProvider::builder()
        .with_reader(reader)
        .with_resource(gen_resources())
        .build())
}

#[cfg(feature = "clap")]
#[derive(clap::Parser, Clone)]
pub struct TracingArgs<L: LogLevel = InfoLevel> {
    #[cfg(any(feature = "otlp", feature = "tracy", feature = "chrome"))]
    /// Which tracers to enable.
    #[arg(long, value_enum, action(clap::ArgAction::Append))]
    tracer: Vec<Tracer>,

    #[clap(flatten)]
    verbosity: Verbosity<L>,
}

/// future that listens to both ctrl-c and sigterm.
// FUTUREWORK: this should maybe belong into another crate…
pub async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("failed to install SIGTERM handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }

    debug!("signal received, shutting down…");
}

#[cfg(feature = "clap")]
impl<L: LogLevel> TracingArgs<L> {
    #[cfg(any(feature = "otlp", feature = "tracy", feature = "chrome"))]
    pub fn tracers(&self) -> EnumSet<Tracer> {
        self.tracer.iter().cloned().collect()
    }
}
