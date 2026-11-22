# Debian 13 (trixie) in both stages, so the binary runs against the glibc it was linked with. The rust tag pins the
# version in rust-toolchain.toml, which is left out of the build so that rustup does not fetch clippy and rustfmt here.
FROM docker.io/library/rust:1.100.0-trixie AS build
WORKDIR /src
COPY Cargo.toml Cargo.lock ./
# Build the dependencies against stub sources first, so this layer stays cached while only src/ changes.
RUN mkdir src && echo 'fn main() {}' > src/main.rs && touch src/lib.rs \
    && cargo build --release --locked \
    && rm -rf src
COPY src ./src
# Make cargo rebuild the crate itself rather than trust the stub's fingerprints.
RUN touch src/main.rs src/lib.rs && cargo build --release --locked

FROM gcr.io/distroless/cc-debian13:nonroot
COPY --from=build /src/target/release/hello-rust /hello-rust
EXPOSE 8080
ENTRYPOINT ["/hello-rust"]
