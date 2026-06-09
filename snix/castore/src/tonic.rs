use hyper_util::rt::TokioIo;
use tokio::net::UnixStream;
use tonic::transport::{Channel, Endpoint};

pub struct TonicConnector {
    endpoint: Endpoint,
    connector: Option<
        tower::util::BoxCloneService<tonic::transport::Uri, TokioIo<UnixStream>, std::io::Error>,
    >,
    /// Whether there's a `wait_connect` in the query string.
    wait_connect: bool,
}

impl TonicConnector {
    /// All URLs support adding `wait-connect=1` as a URL parameter, in which case
    /// the connection is established lazily.
    pub fn from_url(url: &url::Url) -> Result<TonicConnector, self::Error> {
        match url.scheme() {
            "grpc+unix" => {
                if url.has_authority() {
                    return Err(Error::AuthorityDisallowed());
                }

                let connector = tower::service_fn({
                    let url = url.clone();
                    move |_: tonic::transport::Uri| {
                        let unix = UnixStream::connect(url.path().to_string());
                        async move { Ok::<_, std::io::Error>(TokioIo::new(unix.await?)) }
                    }
                });

                // the URL doesn't matter, but we need a custom connector
                Ok(Self {
                    endpoint: Endpoint::from_static("http://[::]:50051"),
                    connector: Some(tower::util::BoxCloneService::new(connector)),
                    wait_connect: url_wants_wait_connect(url),
                })
            }
            _ => {
                // ensure path is empty, not supported with gRPC.
                if !url.path().is_empty() {
                    return Err(Error::PathMayNotBeSet());
                }

                // Stringify the URL and remove the grpc+ prefix.
                // We can't use `url.set_scheme(rest)`, as it disallows
                // setting something http(s) that previously wasn't.
                let unprefixed_url_str = url
                    .as_str()
                    .strip_prefix("grpc+")
                    .ok_or(Error::MissingGRPCPrefix())?;

                // Use the regular tonic transport::Endpoint logic, but unprefixed_url_str,
                // as tonic doesn't know about grpc+http[s].
                let endpoint = Endpoint::from_shared(unprefixed_url_str.to_owned())?;

                let endpoint = if url.scheme() == "grpc+https" {
                    let tls_config = tonic::transport::ClientTlsConfig::new().with_enabled_roots();
                    endpoint.tls_config(tls_config)?
                } else {
                    endpoint
                };

                Ok(Self {
                    endpoint,
                    connector: None,
                    wait_connect: url_wants_wait_connect(url),
                })
            }
        }
    }

    // Tries to connect lazily
    // Will panic if `wait-connect=1` was set in the URL, as connecting
    // non-lazily needs to be async, use [Self::connect] for that.
    pub fn connect_expect_lazy(self) -> Channel {
        if let Some(connector) = self.connector {
            assert!(
                !self.wait_connect,
                "wait-connect URL called with connect_lazy"
            );
            self.endpoint.connect_with_connector_lazy(connector)
        } else {
            assert!(
                !self.wait_connect,
                "wait-connect URL called with connect_lazy"
            );
            self.endpoint.connect_lazy()
        }
    }

    // Tries to connect.
    pub async fn connect(self) -> Result<Channel, Error> {
        Ok(if let Some(connector) = self.connector {
            if !self.wait_connect {
                self.endpoint.connect_with_connector_lazy(connector)
            } else {
                self.endpoint.connect_with_connector(connector).await?
            }
        } else {
            if !self.wait_connect {
                self.endpoint.connect_lazy()
            } else {
                self.endpoint.connect().await?
            }
        })
    }
}

fn url_wants_wait_connect(url: &url::Url) -> bool {
    url.query_pairs()
        .filter(|(k, v)| k == "wait-connect" && v == "1")
        .count()
        > 0
}

/// Turn a [url::Url] to a [Channel] if it can be parsed successfully.
/// It supports the following schemes (and URLs):
///  - `grpc+http://[::1]:8000`, connecting over unencrypted HTTP/2 (h2c)
///  - `grpc+https://[::1]:8000`, connecting over encrypted HTTP/2
///  - `grpc+unix:/path/to/socket`, connecting to a unix domain socket
pub async fn channel_from_url(url: &url::Url) -> Result<Channel, Error> {
    TonicConnector::from_url(url)?.connect().await
}

/// Errors occuring when parsing a gRPC backend URL, or trying to connect to it.
#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("grpc+ prefix is missing from URL")]
    MissingGRPCPrefix(),

    #[error("unix domain sockets URLs should not have authority")]
    AuthorityDisallowed(),

    #[error("path may not be set")]
    PathMayNotBeSet(),

    #[error("transport error: {0}")]
    TransportError(tonic::transport::Error),
}

impl From<tonic::transport::Error> for Error {
    fn from(value: tonic::transport::Error) -> Self {
        Self::TransportError(value)
    }
}

#[cfg(test)]
mod tests {
    use super::channel_from_url;
    use rstest::rstest;
    use url::Url;

    #[rstest]
    /// Correct scheme to connect to a unix socket.
    #[case::valid_unix_socket("grpc+unix:/path/to/somewhere", true)]
    /// Connecting with wait-connect set to 0 succeeds, as that's the default.
    #[case::valid_unix_socket_wait_connect_0("grpc+unix:/path/to/somewhere?wait-connect=0", true)]
    /// Connecting with wait-connect set to 1 fails, as the path doesn't exist.
    #[case::valid_unix_socket_wait_connect_1("grpc+unix:/path/to/somewhere?wait-connect=1", false)]
    /// Correct scheme for unix socket, but setting authority, which is invalid.
    #[case::invalid_unix_socket_with_authority("grpc+unix:///path/to/somewhere", false)]
    /// Correct scheme for unix socket, but setting a host too, which is invalid.
    #[case::invalid_unix_socket_and_host("grpc+unix://host.example/path/to/somewhere", false)]
    /// Correct scheme to connect to localhost, with port 12345
    #[case::valid_ipv6_localhost_port_12345("grpc+http://[::1]:12345", true)]
    /// Correct scheme to connect to localhost over http, without specifying a port.
    #[case::valid_http_host_without_port("grpc+http://localhost", true)]
    /// Correct scheme to connect to localhost over http, without specifying a port.
    #[case::valid_https_host_without_port("grpc+https://localhost", true)]
    /// Correct scheme to connect to localhost over http, but with additional path, which is invalid.
    #[case::invalid_host_and_path("grpc+http://localhost/some-path", false)]
    /// Connecting with wait-connect set to 0 succeeds, as that's the default.
    #[case::valid_host_wait_connect_0("grpc+http://localhost?wait-connect=0", true)]
    /// Connecting with wait-connect set to 1 fails, as the host doesn't exist.
    #[case::valid_host_wait_connect_1_fails("grpc+http://nonexist.invalid?wait-connect=1", false)]
    #[tokio::test]
    async fn test_from_addr_tokio(#[case] uri_str: &str, #[case] is_ok: bool) {
        let url = Url::parse(uri_str).expect("must parse");
        assert_eq!(channel_from_url(&url).await.is_ok(), is_ok)
    }
}
