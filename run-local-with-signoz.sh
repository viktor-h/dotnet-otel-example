#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.signoz-local.yml"

# SigNoz's local OTLP gRPC endpoint (self-host default) usually listens on host port 4317.
SIGNOZ_OTLP_ENDPOINT="${SIGNOZ_OTLP_ENDPOINT:-host.docker.internal:4317}"

# We keep our collector on alternate host ports so it can coexist with local SigNoz (which uses 4317/4318).
LOCAL_COLLECTOR_GRPC_PORT="${LOCAL_COLLECTOR_GRPC_PORT:-14317}"
OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-dotnet-otel-example}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed or not in PATH" >&2
  exit 1
fi

if ! command -v dotnet >/dev/null 2>&1; then
  echo "dotnet is not installed or not in PATH" >&2
  exit 1
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Missing docker compose file: $COMPOSE_FILE" >&2
  exit 1
fi

echo "Starting local infra (collector + postgres) with forwarding to SigNoz at $SIGNOZ_OTLP_ENDPOINT..."
SIGNOZ_OTLP_ENDPOINT="$SIGNOZ_OTLP_ENDPOINT" docker compose -f "$COMPOSE_FILE" up -d

cleanup() {
  echo
  echo "Stopping local infra..."
  docker compose -f "$COMPOSE_FILE" down >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

echo "Starting .NET application (OTLP -> localhost:$LOCAL_COLLECTOR_GRPC_PORT)..."
OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:$LOCAL_COLLECTOR_GRPC_PORT" \
OTEL_SERVICE_NAME="$OTEL_SERVICE_NAME" \
  dotnet run --project "$SCRIPT_DIR/dotnet-otel-example.csproj"
