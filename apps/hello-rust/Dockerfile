FROM docker.io/library/rust:1.100.0 AS build
WORKDIR /src
COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo build --release --locked

FROM gcr.io/distroless/cc-debian12:nonroot
COPY --from=build /src/target/release/hello-rust /hello-rust
EXPOSE 8080
ENTRYPOINT ["/hello-rust"]
