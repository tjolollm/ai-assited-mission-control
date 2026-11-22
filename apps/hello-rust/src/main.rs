use std::{env, io};

use hello_rust::{SHUTDOWN_GRACE, app, listen, port_from_env, serve};
use tokio::signal::unix::{Signal, SignalKind, signal};

#[tokio::main]
async fn main() -> io::Result<()> {
    let port = port_from_env(env::var("PORT").ok().as_deref())
        .map_err(|e| io::Error::new(io::ErrorKind::InvalidInput, e))?;
    // Install the handlers before listening, here in main: a SIGTERM that arrives early is then queued rather than lost
    // (PID 1 ignores signals it has no handler for), and a failure to install one is main's error, not a panic in
    // the task axum spawns for the shutdown future.
    let term = signal(SignalKind::terminate())?;
    let int = signal(SignalKind::interrupt())?;
    let listener = listen(port)?;
    println!("hello-rust listening on {}", listener.local_addr()?);
    match serve(listener, app(), shutdown_signal(term, int), SHUTDOWN_GRACE).await {
        Err(e) if e.kind() == io::ErrorKind::TimedOut => {
            eprintln!("shutdown: {e}");
            Ok(())
        }
        result => result,
    }
}

/// Resolves on SIGTERM, which kubelet sends to stop a pod, or on SIGINT.
async fn shutdown_signal(mut term: Signal, mut int: Signal) {
    tokio::select! {
        _ = term.recv() => {},
        _ = int.recv() => {},
    }
    println!("hello-rust shutting down");
}
