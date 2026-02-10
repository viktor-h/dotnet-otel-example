# dotnet-otel-example

ASP.NET Core example that exports traces and metrics with OpenTelemetry over OTLP and stores weather reports in PostgreSQL.

## Prerequisites

- .NET SDK 10.0
- Docker

## Run locally

From the repo root:

```bash
./run-local.sh
```

This script starts via `docker compose`:

1. An OpenTelemetry Collector on `localhost:4317` using `otel-collector-local.yaml`
2. A PostgreSQL database on `localhost:5432` (`weather` DB)
3. The ASP.NET Core app (`dotnet-otel-example.csproj`)

## API

### Insert a weather report

```bash
curl -X POST http://localhost:5257/weatherforecast \
  -H "Content-Type: application/json" \
  -d '{"date":"2026-02-10","temperatureC":12,"summary":"Cool"}'
```

### Fetch weather reports

```bash
curl http://localhost:5257/weatherforecast
```

## Run with local SigNoz

This mode keeps a local OpenTelemetry Collector in front of SigNoz and also starts PostgreSQL.

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

1. Starts local infra via `docker-compose.signoz-local.yml` (collector + postgres)
2. Exposes collector on host ports `14317` (gRPC) and `14318` (HTTP)
3. Runs the .NET app with `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:14317`
4. Forwards traces/metrics/logs from local collector to SigNoz at `host.docker.internal:4317`

You can override the SigNoz OTLP endpoint:

```bash
SIGNOZ_OTLP_ENDPOINT=host.docker.internal:4317 ./run-local-with-signoz.sh
```

## Configuration

Default DB connection string:

```text
Host=localhost;Port=5432;Database=weather;Username=postgres;Password=postgres
```

Override it with either:

- `ConnectionStrings:WeatherDb` in config
- `WEATHER_DB_CONNECTION` environment variable
