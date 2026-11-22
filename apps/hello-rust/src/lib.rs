//! A service that answers `GET /` with a JSON "hello, world" greeting.

use std::{
    future::{Future, IntoFuture, pending},
    io,
    net::{Ipv4Addr, Ipv6Addr, SocketAddr},
    time::Duration,
};

use axum::{Json, Router, routing::get};
use serde::Serialize;
use socket2::{Domain, Protocol, Socket, Type};
use tokio::{net::TcpListener, sync::oneshot, time::sleep};

/// The port the service listens on when `PORT` is unset or empty.
pub const DEFAULT_PORT: u16 = 8080;

/// How long requests in flight get to finish after the shutdown signal, the same as hello-go and well inside
/// kubelet's default grace period of 30s.
pub const SHUTDOWN_GRACE: Duration = Duration::from_secs(10);

/// The body of the response to `GET /`.
#[derive(Debug, Serialize)]
pub struct Greeting {
    pub message: &'static str,
}

/// The routes of the service: `GET /` answers with the greeting, and any other path is not found.
pub fn app() -> Router {
    Router::new().route("/", get(hello))
}

async fn hello() -> Json<Greeting> {
    Json(Greeting {
        message: "hello, world",
    })
}

/// The port to listen on, from the value of `PORT`: unset or empty means [`DEFAULT_PORT`], as in hello-go.
pub fn port_from_env(value: Option<&str>) -> Result<u16, String> {
    match value {
        None | Some("") => Ok(DEFAULT_PORT),
        Some(p) => p.parse().map_err(|e| format!("PORT={p:?}: {e}")),
    }
}

/// Listens on `port` on every address, IPv6 and IPv4 alike, as Go's `:PORT` does: the socket clears `IPV6_V6ONLY`
/// itself rather than rely on the host's `net.ipv6.bindv6only`. Where the host has no IPv6, it listens on IPv4 alone.
pub fn listen(port: u16) -> io::Result<TcpListener> {
    let socket = match bind(Domain::IPV6, (Ipv6Addr::UNSPECIFIED, port).into(), true) {
        Ok(socket) => socket,
        Err(e) if e.kind() == io::ErrorKind::AddrInUse => return Err(e),
        Err(_) => bind(Domain::IPV4, (Ipv4Addr::UNSPECIFIED, port).into(), false)?,
    };
    TcpListener::from_std(socket.into())
}

fn bind(domain: Domain, addr: SocketAddr, dual_stack: bool) -> io::Result<Socket> {
    let socket = Socket::new(domain, Type::STREAM, Some(Protocol::TCP))?;
    if dual_stack {
        socket.set_only_v6(false)?;
    }
    socket.set_reuse_address(true)?;
    socket.set_nonblocking(true)?;
    socket.bind(&addr.into())?;
    socket.listen(1024)?;
    Ok(socket)
}

/// Serves `app` on `listener` until `shutdown` resolves, then stops taking connections and gives the requests in flight
/// up to `grace` to finish. Returns `Ok` when every request finished, an error of kind `TimedOut` when the grace ran
/// out first, or the error that stopped the server before the shutdown.
pub async fn serve(
    listener: TcpListener,
    app: Router,
    shutdown: impl Future<Output = ()> + Send + 'static,
    grace: Duration,
) -> io::Result<()> {
    let (started_tx, started_rx) = oneshot::channel();
    let server = axum::serve(listener, app)
        .with_graceful_shutdown(async move {
            shutdown.await;
            let _ = started_tx.send(());
        })
        .into_future();
    let deadline = async move {
        match started_rx.await {
            Ok(()) => sleep(grace).await,
            // The server stopped without a shutdown; its own result decides.
            Err(_) => pending().await,
        }
    };
    tokio::select! {
        // When the server finishes on the same poll as the deadline, every request did finish: report that.
        biased;
        result = server => result,
        () = deadline => Err(io::Error::new(
            io::ErrorKind::TimedOut,
            format!("requests still running after {grace:?} were cut off"),
        )),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{
        body::Body,
        http::{Method, Request, StatusCode, header},
    };
    use http_body_util::BodyExt;
    use std::{
        sync::{
            Arc,
            atomic::{AtomicBool, Ordering},
        },
        time::Instant,
    };
    use tokio::{
        io::{AsyncReadExt, AsyncWriteExt},
        net::TcpStream,
        sync::Notify,
    };
    use tower::ServiceExt;

    async fn send(method: Method, uri: &str) -> axum::response::Response {
        app()
            .oneshot(
                Request::builder()
                    .method(method)
                    .uri(uri)
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap()
    }

    #[tokio::test]
    async fn hello_returns_json_greeting() {
        let resp = send(Method::GET, "/").await;

        assert_eq!(resp.status(), StatusCode::OK);
        assert_eq!(resp.headers()[header::CONTENT_TYPE], "application/json");
        let body = resp.into_body().collect().await.unwrap().to_bytes();
        // Byte for byte the same body as hello-go sends.
        assert_eq!(&body[..], br#"{"message":"hello, world"}"#);
    }

    #[tokio::test]
    async fn unknown_path_is_not_found() {
        assert_eq!(
            send(Method::GET, "/nope").await.status(),
            StatusCode::NOT_FOUND
        );
    }

    #[tokio::test]
    async fn other_methods_are_not_allowed() {
        assert_eq!(
            send(Method::POST, "/").await.status(),
            StatusCode::METHOD_NOT_ALLOWED
        );
    }

    #[test]
    fn port_from_env_defaults_when_unset_or_empty() {
        assert_eq!(port_from_env(None), Ok(DEFAULT_PORT));
        assert_eq!(port_from_env(Some("")), Ok(DEFAULT_PORT));
        assert_eq!(port_from_env(Some("9000")), Ok(9000));
        assert!(port_from_env(Some("http")).is_err());
    }

    #[tokio::test]
    async fn listen_accepts_ipv4_and_ipv6() {
        let listener = listen(0).unwrap();
        let port = listener.local_addr().unwrap().port();
        tokio::spawn(async move {
            loop {
                let _ = listener.accept().await;
            }
        });
        TcpStream::connect((Ipv4Addr::LOCALHOST, port))
            .await
            .expect("IPv4 connection");
        // Where the host has IPv6, the same socket takes IPv6 too.
        if std::net::TcpListener::bind((Ipv6Addr::LOCALHOST, 0)).is_ok() {
            TcpStream::connect((Ipv6Addr::LOCALHOST, port))
                .await
                .expect("IPv6 connection");
        }
    }

    /// Starts `serve` with a `GET /slow` route that runs `slow`, sends one request to it, and returns the shutdown
    /// trigger, `serve`'s task and the request's task, once the request is in the handler.
    async fn serve_slow_request<F, Fut>(
        slow: F,
        grace: Duration,
    ) -> (
        oneshot::Sender<()>,
        tokio::task::JoinHandle<io::Result<()>>,
        tokio::task::JoinHandle<String>,
    )
    where
        F: Fn() -> Fut + Clone + Send + Sync + 'static,
        Fut: Future<Output = &'static str> + Send + 'static,
    {
        let entered = Arc::new(Notify::new());
        let entered_in_handler = entered.clone();
        let router = Router::new().route(
            "/slow",
            get(move || {
                let entered = entered_in_handler.clone();
                let slow = slow.clone();
                async move {
                    entered.notify_one();
                    slow().await
                }
            }),
        );
        let listener = TcpListener::bind((Ipv4Addr::LOCALHOST, 0)).await.unwrap();
        let addr = listener.local_addr().unwrap();
        let (shutdown_tx, shutdown_rx) = oneshot::channel::<()>();
        let server = tokio::spawn(serve(
            listener,
            router,
            async move {
                let _ = shutdown_rx.await;
            },
            grace,
        ));
        let request = tokio::spawn(async move {
            let mut stream = TcpStream::connect(addr).await.unwrap();
            stream
                .write_all(b"GET /slow HTTP/1.1\r\nHost: test\r\nConnection: close\r\n\r\n")
                .await
                .unwrap();
            let mut response = String::new();
            let _ = stream.read_to_string(&mut response).await;
            response
        });
        entered.notified().await;
        (shutdown_tx, server, request)
    }

    #[tokio::test]
    async fn serve_lets_requests_in_flight_finish() {
        let finished = Arc::new(AtomicBool::new(false));
        let finished_in_handler = finished.clone();
        let (shutdown, server, request) = serve_slow_request(
            move || {
                let finished = finished_in_handler.clone();
                async move {
                    sleep(Duration::from_millis(300)).await;
                    finished.store(true, Ordering::SeqCst);
                    "done"
                }
            },
            Duration::from_secs(5),
        )
        .await;

        shutdown.send(()).unwrap();
        let result = tokio::time::timeout(Duration::from_secs(5), server)
            .await
            .expect("serve returns after shutdown")
            .unwrap();

        assert!(result.is_ok(), "serve = {result:?}, want Ok");
        assert!(
            finished.load(Ordering::SeqCst),
            "serve returned before the request in flight finished"
        );
        let response = request.await.unwrap();
        assert!(
            response.starts_with("HTTP/1.1 200") && response.ends_with("done"),
            "request in flight got {response:?}"
        );
    }

    #[tokio::test]
    async fn serve_cuts_off_requests_after_grace() {
        let (shutdown, server, _request) =
            serve_slow_request(pending::<&'static str>, Duration::from_millis(200)).await;

        let begin = Instant::now();
        shutdown.send(()).unwrap();
        let result = tokio::time::timeout(Duration::from_secs(5), server)
            .await
            .expect("serve gives up on a stuck request after the grace period")
            .unwrap();

        assert_eq!(
            result.map_err(|e| e.kind()),
            Err(io::ErrorKind::TimedOut),
            "serve should report the cut-off requests"
        );
        assert!(
            begin.elapsed() < Duration::from_secs(2),
            "serve took {:?}, want about the 200ms grace",
            begin.elapsed()
        );
    }
}
