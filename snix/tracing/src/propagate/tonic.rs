#[cfg(feature = "otlp")]
struct MetadataInjector<'a>(&'a mut tonic::metadata::MetadataMap);

#[cfg(feature = "otlp")]
impl opentelemetry::propagation::Injector for MetadataInjector<'_> {
    fn set(&mut self, key: &str, value: String) {
        use tonic::metadata::{MetadataKey, MetadataValue};
        use tracing::warn;

        match MetadataKey::from_bytes(key.as_bytes()) {
            Ok(key) => match MetadataValue::try_from(&value) {
                Ok(value) => {
                    self.0.insert(key, value);
                }
                Err(error) => warn!(value, error = format!("{error:#}"), "parse metadata value"),
            },
            Err(error) => warn!(key, error = format!("{error:#}"), "parse metadata key"),
        }
    }
}

/// Trace context propagation: send the trace context by injecting it into the metadata of the given
/// request. This only injects the current span if the otlp feature is also enabled.
#[allow(unused_mut)]
pub fn send_trace<T>(
    mut request: tonic::Request<T>,
) -> Result<tonic::Request<T>, Box<tonic::Status>> {
    #[cfg(feature = "otlp")]
    {
        use tracing_opentelemetry::OpenTelemetrySpanExt;
        opentelemetry::global::get_text_map_propagator(|propagator| {
            let context = tracing::Span::current().context();
            propagator.inject_context(&context, &mut MetadataInjector(request.metadata_mut()))
        });
    }
    Ok(request)
}
