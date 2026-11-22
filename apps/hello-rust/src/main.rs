use std::{env, io};

use hello_rust::{SHUTDOWN_GRACE, app, listen, port_from_env, serve};
use tokio::signal::unix::{SignalKind, signal};

#[tokio::main]
async fn main() -> io::Result<()> {
    let port = port_from_env(env::var("PORT").ok().as_deref())
        .map_err(|e| io::Error::new(io::ErrorKind::InvalidInput, e))?;
    let listener = listen(port)?;
    println!("hello-rust listening on {}", listener.local_addr()?);
    match serve(listener, app(), shutdown_signal(), SHUTDOWN_GRACE).await {
        Err(e) if e.kind() == io::ErrorKind::TimedOut => {
            eprintln!("shutdown: {e}");
            Ok(())
        }
        result => result,
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
