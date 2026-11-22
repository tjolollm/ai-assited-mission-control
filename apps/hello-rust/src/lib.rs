//! A service that answers `GET /` with a JSON "hello, world" greeting.

use axum::{Json, Router, routing::get};
use serde::Serialize;

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

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{
        body::Body,
        http::{Method, Request, StatusCode, header},
    };
    use http_body_util::BodyExt;
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
}
