// ============================================
// Observability Service Extensions
// Add to your Services folder or Extensions folder
// ============================================

using Azure.Identity;
using Azure.Monitor.OpenTelemetry.AspNetCore;
using Microsoft.ApplicationInsights.Extensibility;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

namespace LoyaltyPlatform.Extensions;

public static class ObservabilityExtensions
{
    /// <summary>
    /// Adds comprehensive observability: Application Insights, OpenTelemetry, health checks
    /// </summary>
    public static IServiceCollection AddLoyaltyObservability(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment environment)
    {
        var serviceName = configuration["OpenTelemetry:ServiceName"] ?? "loyalty-api";
        var serviceVersion = configuration["OpenTelemetry:ServiceVersion"] ?? "1.0.0";

        // Application Insights with OpenTelemetry
        services.AddOpenTelemetry()
            .ConfigureResource(resource => resource
                .AddService(serviceName, serviceVersion: serviceVersion)
                .AddAttributes(new Dictionary<string, object>
                {
                    ["deployment.environment"] = environment.EnvironmentName,
                    ["service.namespace"] = "loyalty-platform"
                }))
            .WithTracing(tracing =>
            {
                tracing
                    .AddSource(serviceName)
                    .AddSource("Azure.Messaging.ServiceBus")
                    .AddAspNetCoreInstrumentation(options =>
                    {
                        options.RecordException = true;
                        options.Filter = httpContext =>
                        {
                            // Skip health check endpoints
                            var path = httpContext.Request.Path.Value;
                            return path != null && !path.StartsWith("/health");
                        };
                    })
                    .AddHttpClientInstrumentation(options =>
                    {
                        options.RecordException = true;
                    })
                    .AddEntityFrameworkCoreInstrumentation(options =>
                    {
                        options.SetDbStatementForText = true;
                    })
                    .AddRedisInstrumentation();

                if (!environment.IsDevelopment())
                {
                    // Sampling in production
                    var samplingRatio = configuration.GetValue<double>("OpenTelemetry:Tracing:SamplingRatio", 0.1);
                    tracing.SetSampler(new TraceIdRatioBasedSampler(samplingRatio));
                }
            })
            .WithMetrics(metrics =>
            {
                metrics
                    .AddAspNetCoreInstrumentation()
                    .AddHttpClientInstrumentation()
                    .AddRuntimeInstrumentation()
                    .AddProcessInstrumentation()
                    // Custom loyalty metrics
                    .AddMeter("LoyaltyPlatform.Points")
                    .AddMeter("LoyaltyPlatform.Redemptions")
                    .AddMeter("LoyaltyPlatform.Tiers");

                // Prometheus exporter
                if (configuration.GetValue<bool>("OpenTelemetry:Metrics:Exporters:Prometheus:Enabled", true))
                {
                    metrics.AddPrometheusExporter();
                }
            })
            .UseAzureMonitor(options =>
            {
                options.ConnectionString = configuration["ApplicationInsights:ConnectionString"];
            });

        // Custom telemetry initializer for loyalty context
        services.AddSingleton<ITelemetryInitializer, LoyaltyTelemetryInitializer>();

        // Health checks
        services.AddLoyaltyHealthChecks(configuration);

        return services;
    }

    private static IServiceCollection AddLoyaltyHealthChecks(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var healthChecks = services.AddHealthChecks();

        // SQL Server
        if (configuration.GetValue<bool>("HealthChecks:Dependencies:Sql", true))
        {
            healthChecks.AddSqlServer(
                configuration.GetConnectionString("LoyaltyDb")!,
                name: "sql",
                tags: new[] { "db", "sql", "ready" });
        }

        // Cosmos DB
        if (configuration.GetValue<bool>("HealthChecks:Dependencies:Cosmos", true))
        {
            healthChecks.AddAzureCosmosDB(
                configuration["CosmosDb:ConnectionString"]!,
                name: "cosmos",
                tags: new[] { "db", "cosmos", "ready" });
        }

        // Redis
        if (configuration.GetValue<bool>("HealthChecks:Dependencies:Redis", true))
        {
            healthChecks.AddRedis(
                configuration["Redis:ConnectionString"]!,
                name: "redis",
                tags: new[] { "cache", "redis", "ready" });
        }

        // Service Bus
        if (configuration.GetValue<bool>("HealthChecks:Dependencies:ServiceBus", true))
        {
            healthChecks.AddAzureServiceBusQueue(
                configuration["ServiceBus:ConnectionString"]!,
                configuration["ServiceBus:Queues:PointAccruals:QueueName"]!,
                name: "servicebus",
                tags: new[] { "messaging", "servicebus", "ready" });
        }

        // Key Vault
        if (configuration.GetValue<bool>("HealthChecks:Dependencies:KeyVault", true))
        {
            healthChecks.AddAzureKeyVault(
                new Uri(configuration["KeyVault:VaultUri"]!),
                new DefaultAzureCredential(),
                options => { },
                name: "keyvault",
                tags: new[] { "secrets", "keyvault", "ready" });
        }

        return services;
    }
}

/// <summary>
/// Adds loyalty-specific context to all telemetry
/// </summary>
public class LoyaltyTelemetryInitializer : ITelemetryInitializer
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public LoyaltyTelemetryInitializer(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    public void Initialize(Microsoft.ApplicationInsights.Channel.ITelemetry telemetry)
    {
        var context = _httpContextAccessor.HttpContext;
        if (context == null) return;

        // Add customer ID if available
        if (context.User.Identity?.IsAuthenticated == true)
        {
            var customerId = context.User.FindFirst("sub")?.Value 
                ?? context.User.FindFirst("oid")?.Value;
            
            if (!string.IsNullOrEmpty(customerId))
            {
                telemetry.Context.User.Id = customerId;
                
                if (telemetry is Microsoft.ApplicationInsights.DataContracts.ISupportProperties propTelemetry)
                {
                    propTelemetry.Properties["CustomerId"] = customerId;
                }
            }
        }

        // Add correlation ID
        if (context.Request.Headers.TryGetValue("X-Correlation-ID", out var correlationId))
        {
            if (telemetry is Microsoft.ApplicationInsights.DataContracts.ISupportProperties propTelemetry)
            {
                propTelemetry.Properties["CorrelationId"] = correlationId.ToString();
            }
        }
    }
}
