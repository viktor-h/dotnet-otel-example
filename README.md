# dotnet-otel-example

ASP.NET Core example that exports traces and metrics with OpenTelemetry over OTLP.

## Prerequisites

- .NET SDK 10.0
- Docker

## Run locally

From the repo root:

```bash
./run-local.sh
```

This script starts:

1. An OpenTelemetry Collector container on `localhost:4317` using `otel-collector-local.yaml`
2. The ASP.NET Core app (`dotnet-otel-example.csproj`)

## Test the endpoint

In a second terminal:

```bash
curl http://localhost:5257/weatherforecast
```

You should see telemetry output in the collector logs (debug exporter).

## Run with local SigNoz

This mode keeps your local OpenTelemetry Collector in the path and forwards data to SigNoz.

### 1) Start SigNoz (self-host)

One option is the official SigNoz Docker install:

```bash
git clone -b main https://github.com/SigNoz/signoz.git /tmp/signoz
cd /tmp/signoz/deploy/
docker compose up -d
```

SigNoz UI is typically available at `http://localhost:8080`.

### 2) Start app + local collector forwarding to SigNoz

From this repo root:

```bash
./run-local-with-signoz.sh
```

What this does:

1. Starts your local collector using `otel-collector-signoz-local.yaml`
2. Exposes it on host ports `14317` (gRPC) and `14318` (HTTP)
3. Runs the .NET app with `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:14317`
4. Forwards traces/metrics/logs from the local collector to SigNoz at `host.docker.internal:4317`

You can override the SigNoz OTLP endpoint:

```bash
SIGNOZ_OTLP_ENDPOINT=host.docker.internal:4317 ./run-local-with-signoz.sh
```

### 3) Generate telemetry

In a second terminal:

```bash
curl http://localhost:5257/weatherforecast
```

Then open SigNoz and check traces/metrics in the UI.
