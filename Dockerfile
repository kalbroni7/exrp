FROM golang:1.22.7 AS base
USER root
RUN apt update && \
    apt-get install -y \
        build-essential \
        ca-certificates \
        curl
RUN curl https://get.ignite.com/cli@v0.27.2! | bash
WORKDIR /go/src/github.com/Peersyst/exrp
COPY . .


FROM base AS build
ARG VERSION=0.0.0
RUN ignite chain build --release --release.prefix exrp_$VERSION -t linux:amd64 -v
RUN tar -xf /go/src/github.com/Peersyst/exrp/release/exrp_${VERSION}_linux_amd64.tar.gz -C /usr/bin


FROM base AS integration
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin
RUN golangci-lint run
# Unit tests
RUN go test $(go list ./... | grep -v github.com/Peersyst/exrp/tests/e2e/poa)
# End to end tests
# TODO: Temporary disabled e2e tests
# RUN TEST_CLEANUP_DIR=false go test -p 1 -v -timeout 30m ./tests/e2e/...
RUN touch /test.lock

FROM golang:1.22.7 AS release
WORKDIR /
COPY --from=integration /test.lock /test.lock
COPY --from=build /go/src/github.com/Peersyst/exrp/release /binaries
COPY --from=build /usr/bin/exrpd /usr/bin/exrpd
ENTRYPOINT ["/bin/sh", "-ec"]
CMD ["exrpd"]