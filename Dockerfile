# Build the manager binary
FROM golang:1.23 AS builder
ARG TARGETOS
ARG TARGETARCH

WORKDIR /workspace
# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# Copy must-gather scripts
COPY must-gather/ must-gather/

# Copy the go source
COPY cmd/main.go cmd/main.go
COPY api/ api/
COPY pkg/ pkg/
COPY internal/ internal/

# Build
# the GOARCH has not a default value to allow the binary be built according to the host where the command
# was called. For example, if we call make docker-build in a local env which has the Apple Silicon M1 SO
# the docker BUILDPLATFORM arg will be linux/arm64 when for Apple x86 it will be linux/amd64. Therefore,
# by leaving it empty we can ensure that the container and binary shipped on it will have the same platform.
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} \
  go build -a -o manager cmd/main.go

FROM quay.io/openshift/origin-cli:4.13 AS origincli

FROM registry.access.redhat.com/ubi9-minimal:9.2
RUN INSTALL_PKGS=" \
  rsync \
  tar \
  " && \
  microdnf install -y $INSTALL_PKGS && \
  microdnf clean all
WORKDIR /
COPY --from=builder /workspace/manager .
COPY --from=builder /workspace/must-gather/* /usr/bin/
COPY --from=origincli /usr/bin/oc /usr/bin
USER 65532:65532

ENTRYPOINT ["/manager"]
