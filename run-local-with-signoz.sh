#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/otel-collector-signoz-local.yaml"

# SigNoz's local OTLP gRPC endpoint (self-host default) usually listens on host port 4317.
SIGNOZ_OTLP_ENDPOINT="${SIGNOZ_OTLP_ENDPOINT:-host.docker.internal:4317}"

# We keep our collector on alternate host ports so it can coexist with local SigNoz (which uses 4317/4318).
LOCAL_COLLECTOR_GRPC_PORT="${LOCAL_COLLECTOR_GRPC_PORT:-14317}"
LOCAL_COLLECTOR_HTTP_PORT="${LOCAL_COLLECTOR_HTTP_PORT:-14318}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed or not in PATH" >&2
  exit 1
fi

if ! command -v dotnet >/dev/null 2>&1; then
  echo "dotnet is not installed or not in PATH" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing collector config: $CONFIG_FILE" >&2
  exit 1
fi

echo "Starting OpenTelemetry Collector (forwarding to SigNoz at $SIGNOZ_OTLP_ENDPOINT)..."
docker run --rm \
  -p "$LOCAL_COLLECTOR_GRPC_PORT:4317" \
  -p "$LOCAL_COLLECTOR_HTTP_PORT:4318" \
  --add-host=host.docker.internal:host-gateway \
  -e SIGNOZ_OTLP_ENDPOINT="$SIGNOZ_OTLP_ENDPOINT" \
  -v "$CONFIG_FILE:/etc/otelcol-contrib/config.yaml:ro" \
  otel/opentelemetry-collector-contrib:latest &
COLLECTOR_PID=$!

cleanup() {
  if kill -0 "$COLLECTOR_PID" >/dev/null 2>&1; then
    echo
    echo "Stopping OpenTelemetry Collector..."
    kill "$COLLECTOR_PID" >/dev/null 2>&1 || true
    wait "$COLLECTOR_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

echo "Starting .NET application (OTLP -> localhost:$LOCAL_COLLECTOR_GRPC_PORT)..."
OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:$LOCAL_COLLECTOR_GRPC_PORT" \
  dotnet run --project "$SCRIPT_DIR/dotnet-otel-example.csproj"
