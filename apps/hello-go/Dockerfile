FROM docker.io/library/golang:1.27.4 AS build
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /hello-go .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /hello-go /hello-go
EXPOSE 8080
ENTRYPOINT ["/hello-go"]
