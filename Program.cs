using Npgsql;
using OpenTelemetry;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);

builder.Logging.ClearProviders();
builder.Logging.AddSimpleConsole(options =>
{
    options.TimestampFormat = "HH:mm:ss ";
    options.SingleLine = true;
});

builder.Services.AddOpenApi();

var weatherDbConnectionString =
    builder.Configuration.GetConnectionString("WeatherDb")
    ?? Environment.GetEnvironmentVariable("WEATHER_DB_CONNECTION")
    ?? "Host=localhost;Port=5432;Database=weather;Username=postgres;Password=postgres";

builder.Services.AddSingleton(_ =>
{
    var dataSourceBuilder = new NpgsqlDataSourceBuilder(weatherDbConnectionString);

    dataSourceBuilder.ConfigureTracing(options =>
        options.ConfigureCommandFilter(cmd =>
            !cmd.CommandText.StartsWith("BEGIN", StringComparison.OrdinalIgnoreCase)
            && !cmd.CommandText.StartsWith("COMMIT", StringComparison.OrdinalIgnoreCase)
            && !cmd.CommandText.StartsWith("ROLLBACK", StringComparison.OrdinalIgnoreCase)
        )
    );

    return dataSourceBuilder.Build();
});

builder
    .Services.AddOpenTelemetry()
    .UseOtlpExporter()
    .WithLogging()
    .WithTracing(t =>
        t.AddAspNetCoreInstrumentation()
            .AddNpgsql()
            .AddHttpClientInstrumentation(options =>
            {
                options.RecordException = true;
                options.EnrichWithHttpRequestMessage = (activity, request) =>
                {
                    activity.SetTag("http.request.method", request.Method);
                    activity.SetTag("http.request.url", request.RequestUri);
                };
                options.EnrichWithHttpResponseMessage = (activity, response) =>
                    activity.SetTag("http.response.status_code", response.StatusCode);
            })
    )
    .WithMetrics(m =>
        m.AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddRuntimeInstrumentation()
            .AddMeter("Npgsql")
    );

var app = builder.Build();

var otlpEndpoint = Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT");
if (
    !string.IsNullOrWhiteSpace(otlpEndpoint)
    && Uri.TryCreate(otlpEndpoint, UriKind.Absolute, out var uri)
)
{
    app.Logger.LogInformation(
        "  OTLP target host: {Host}, port: {Port}, scheme: {Scheme}",
        uri.Host,
        uri.Port,
        uri.Scheme
    );
}

var dataSource = app.Services.GetRequiredService<NpgsqlDataSource>();
await EnsureWeatherTableAsync(dataSource, app.Logger, app.Lifetime.ApplicationStopping);

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();

app.MapGet(
        "/weatherforecast",
        async (NpgsqlDataSource db, CancellationToken cancellationToken) =>
        {
            await using var cmd = db.CreateCommand(
                """
                SELECT report_date, temperature_c, summary
                FROM weather_reports
                ORDER BY report_date, id
                """
            );

            await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
            var forecast = new List<WeatherForecast>();

            while (await reader.ReadAsync(cancellationToken))
            {
                forecast.Add(
                    new WeatherForecast(
                        reader.GetFieldValue<DateOnly>(0),
                        reader.GetInt32(1),
                        reader.IsDBNull(2) ? null : reader.GetString(2)
                    )
                );
            }

            return forecast;
        }
    )
    .WithName("GetWeatherForecast");

app.MapPost(
    "/weatherforecast",
    async (
        CreateWeatherForecastRequest request,
        NpgsqlDataSource db,
        CancellationToken cancellationToken
    ) =>
    {
        await using var cmd = db.CreateCommand(
            """
            INSERT INTO weather_reports (report_date, temperature_c, summary)
            VALUES ($1, $2, $3)
            RETURNING id
            """
        );

        cmd.Parameters.AddWithValue(request.Date);
        cmd.Parameters.AddWithValue(request.TemperatureC);
        cmd.Parameters.Add(
            new NpgsqlParameter { Value = (object?)request.Summary ?? DBNull.Value }
        );

        var insertedId = (long)(await cmd.ExecuteScalarAsync(cancellationToken))!;

        return Results.Created(
            $"/weatherforecast/{insertedId}",
            new WeatherForecast(request.Date, request.TemperatureC, request.Summary)
        );
    }
);

app.Run();

static async Task EnsureWeatherTableAsync(
    NpgsqlDataSource dataSource,
    ILogger logger,
    CancellationToken cancellationToken
)
{
    await using var cmd = dataSource.CreateCommand(
        """
        CREATE TABLE IF NOT EXISTS weather_reports (
            id BIGSERIAL PRIMARY KEY,
            report_date DATE NOT NULL,
            temperature_c INTEGER NOT NULL,
            summary TEXT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
        """
    );

    await cmd.ExecuteNonQueryAsync(cancellationToken);
    logger.LogInformation("Ensured weather_reports table exists");
}

record CreateWeatherForecastRequest(DateOnly Date, int TemperatureC, string? Summary);

record WeatherForecast(DateOnly Date, int TemperatureC, string? Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}
