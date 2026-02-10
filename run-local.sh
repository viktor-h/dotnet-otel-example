#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.local.yml"
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

echo "Starting local infra (collector + postgres) via docker compose..."
docker compose -f "$COMPOSE_FILE" up -d

cleanup() {
  echo
  echo "Stopping local infra..."
  docker compose -f "$COMPOSE_FILE" down >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

echo "Starting .NET application..."
OTEL_SERVICE_NAME="$OTEL_SERVICE_NAME" \
  dotnet run --project "$SCRIPT_DIR/dotnet-otel-example.csproj"
