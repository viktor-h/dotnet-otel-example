#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/otel-collector-local.yaml"

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

echo "Starting OpenTelemetry Collector..."
docker run --rm -p 4317:4317 \
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

echo "Starting .NET application..."
dotnet run --project "$SCRIPT_DIR/dotnet-otel-example.csproj"
