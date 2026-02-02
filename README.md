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
