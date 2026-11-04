# syntax=docker/dockerfile:1.7
# Unofficial container image: Mistgate PANEL only, not the node agent.
FROM --platform=$BUILDPLATFORM node:22-bookworm-slim AS web-builder
WORKDIR /src/web
COPY web/package.json web/pnpm-lock.yaml ./
RUN npm install --global pnpm@10.33.2 && pnpm install --frozen-lockfile
COPY web/ ./
RUN pnpm build

FROM --platform=$BUILDPLATFORM golang:1.27-bookworm AS go-builder
WORKDIR /src
ARG TARGETOS=linux
ARG TARGETARCH
ARG BUILD_VERSION=git-dev
ARG BUILD_UNIX=0

# The project replaces the upstream Hysteria module with a local module.
COPY go.mod go.sum ./
COPY third_party/hysteria-core/go.mod third_party/hysteria-core/go.sum ./third_party/hysteria-core/
RUN --mount=type=cache,target=/go/pkg/mod go mod download

COPY . .
# The Go binary embeds web/dist; replace the repository placeholder with the built SPA.
COPY --from=web-builder /src/web/dist ./web/dist

RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    set -eux; \
    test "$TARGETOS" = linux; \
    case "$TARGETARCH" in amd64|arm64) ;; *) echo "Unsupported arch: $TARGETARCH" >&2; exit 1 ;; esac; \
    release_key="$(sed -n 's/^readonly RELEASE_PUBLIC_KEY_BASE64="\([^"]*\)"$/\1/p' scripts/install.sh)"; \
    test -n "$release_key"; \
    mkdir -p /out; \
    CGO_ENABLED=0 GOOS="$TARGETOS" GOARCH="$TARGETARCH" go build -trimpath -buildvcs=false \
      -ldflags "-s -w -X github.com/mistgate/mistgate/internal/buildinfo.Version=$BUILD_VERSION -X github.com/mistgate/mistgate/internal/buildinfo.Built=$BUILD_UNIX -X github.com/mistgate/mistgate/internal/buildinfo.ReleaseKey=$release_key" \
      -o /out/mistgate ./cmd/mistgate

FROM alpine:3.23
RUN apk add --no-cache ca-certificates tzdata
COPY --from=go-builder /out/mistgate /usr/local/bin/mistgate
EXPOSE 80/tcp 443/tcp
VOLUME ["/var/lib/mistgate"]
ENTRYPOINT ["/usr/local/bin/mistgate"]
CMD ["version"]
