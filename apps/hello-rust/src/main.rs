use std::env;

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let port = env::var("PORT").unwrap_or_else(|_| "8080".to_owned());
    let addr = format!("0.0.0.0:{port}");
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    println!("hello-rust listening on {addr}");
    axum::serve(listener, hello_rust::app()).await
}
