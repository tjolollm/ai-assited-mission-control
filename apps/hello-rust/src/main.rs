use std::{env, io, net::Ipv6Addr};

use tokio::{
    net::TcpListener,
    signal::unix::{SignalKind, signal},
};

#[tokio::main]
async fn main() -> io::Result<()> {
    let port: u16 = env::var("PORT")
        .ok()
        .map(|p| p.parse())
        .transpose()
        .map_err(|e| io::Error::new(io::ErrorKind::InvalidInput, format!("PORT: {e}")))?
        .unwrap_or(8080);
    let listener = listen(port).await?;
    println!("hello-rust listening on {}", listener.local_addr()?);
    axum::serve(listener, hello_rust::app())
        .with_graceful_shutdown(shutdown_signal())
        .await
}

/// Listens on all addresses, IPv6 and IPv4, as Go's `:PORT` does, and falls back to IPv4 alone where the host has no
/// IPv6.
async fn listen(port: u16) -> io::Result<TcpListener> {
    match TcpListener::bind((Ipv6Addr::UNSPECIFIED, port)).await {
        Ok(listener) => Ok(listener),
        Err(e) if e.kind() == io::ErrorKind::AddrInUse => Err(e),
        Err(_) => TcpListener::bind(("0.0.0.0", port)).await,
    }
}

/// Resolves on SIGTERM, which kubelet sends to stop a pod, or on SIGINT. As PID 1 in a container the process gets no
/// default handling of either, so without this it would wait out the grace period and be killed.
async fn shutdown_signal() {
    let mut term = signal(SignalKind::terminate()).expect("installing SIGTERM handler");
    let mut int = signal(SignalKind::interrupt()).expect("installing SIGINT handler");
    tokio::select! {
        _ = term.recv() => {},
        _ = int.recv() => {},
    }
    println!("hello-rust shutting down");
}
