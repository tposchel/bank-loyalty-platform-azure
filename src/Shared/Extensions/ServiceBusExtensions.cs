// ============================================
// Service Bus Extensions for Async Operations
// Add to your Services folder or Extensions folder
// ============================================

using System.Text.Json;
using Azure.Identity;
using Azure.Messaging.ServiceBus;
using Microsoft.Extensions.Options;

namespace LoyaltyPlatform.Extensions;

public static class ServiceBusExtensions
{
    /// <summary>
    /// Adds Service Bus client and message publishers
    /// </summary>
    public static IServiceCollection AddLoyaltyServiceBus(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.Configure<ServiceBusOptions>(configuration.GetSection("ServiceBus"));

        // Service Bus client with Workload Identity
        services.AddSingleton(sp =>
        {
            var options = sp.GetRequiredService<IOptions<ServiceBusOptions>>().Value;
            return new ServiceBusClient(
                options.FullyQualifiedNamespace,
                new DefaultAzureCredential());
        });

        // Message publishers
        services.AddSingleton<IPointAccrualPublisher, PointAccrualPublisher>();
        services.AddSingleton<IPointRedemptionPublisher, PointRedemptionPublisher>();
        services.AddSingleton<ILoyaltyEventPublisher, LoyaltyEventPublisher>();

        return services;
    }

    /// <summary>
    /// Adds Service Bus message processors (for worker services)
    /// </summary>
    public static IServiceCollection AddLoyaltyServiceBusProcessors(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddLoyaltyServiceBus(configuration);

        // Hosted services for message processing
        services.AddHostedService<PointAccrualProcessor>();
        services.AddHostedService<PointRedemptionProcessor>();
        services.AddHostedService<TierCalculationProcessor>();

        return services;
    }
}

public class ServiceBusOptions
{
    public string FullyQualifiedNamespace { get; set; } = string.Empty;
    public ServiceBusQueueOptions Queues { get; set; } = new();
    public ServiceBusTopicOptions Topics { get; set; } = new();
}

public class ServiceBusQueueOptions
{
    public QueueConfig PointAccruals { get; set; } = new();
    public QueueConfig PointRedemptions { get; set; } = new();
    public QueueConfig TierCalculations { get; set; } = new();
}

public class QueueConfig
{
    public string QueueName { get; set; } = string.Empty;
    public int MaxConcurrentCalls { get; set; } = 10;
    public int PrefetchCount { get; set; } = 20;
    public bool AutoCompleteMessages { get; set; }
    public bool RequiresSession { get; set; }
}

public class ServiceBusTopicOptions
{
    public TopicConfig LoyaltyEvents { get; set; } = new();
}

public class TopicConfig
{
    public string TopicName { get; set; } = string.Empty;
}

// ============================================
// Message Contracts
// ============================================

public record PointAccrualMessage(
    string CustomerId,
    int Points,
    string TransactionId,
    string TransactionType,
    DateTimeOffset Timestamp,
    Dictionary<string, string>? Metadata = null);

public record PointRedemptionMessage(
    string CustomerId,
    int Points,
    string RewardId,
    string RedemptionId,
    DateTimeOffset Timestamp);

public record TierCalculationMessage(
    string CustomerId,
    string Reason,  // "PointsChanged", "PeriodEnd", "Manual"
    DateTimeOffset Timestamp);

public record LoyaltyEvent(
    string EventType,  // "PointsEarned", "PointsRedeemed", "TierChanged", etc.
    string CustomerId,
    int? PointValue,
    Dictionary<string, object>? Data,
    DateTimeOffset Timestamp);

// ============================================
// Publishers
// ============================================

public interface IPointAccrualPublisher
{
    Task PublishAsync(PointAccrualMessage message, CancellationToken ct = default);
    Task PublishBatchAsync(IEnumerable<PointAccrualMessage> messages, CancellationToken ct = default);
}

public class PointAccrualPublisher : IPointAccrualPublisher, IAsyncDisposable
{
    private readonly ServiceBusSender _sender;
    private readonly ILogger<PointAccrualPublisher> _logger;

    public PointAccrualPublisher(
        ServiceBusClient client,
        IOptions<ServiceBusOptions> options,
        ILogger<PointAccrualPublisher> logger)
    {
        _sender = client.CreateSender(options.Value.Queues.PointAccruals.QueueName);
        _logger = logger;
    }

    public async Task PublishAsync(PointAccrualMessage message, CancellationToken ct = default)
    {
        var sbMessage = new ServiceBusMessage(JsonSerializer.SerializeToUtf8Bytes(message))
        {
            MessageId = message.TransactionId,
            ContentType = "application/json",
            Subject = message.TransactionType,
            ApplicationProperties =
            {
                ["CustomerId"] = message.CustomerId,
                ["Points"] = message.Points
            }
        };

        await _sender.SendMessageAsync(sbMessage, ct);
        _logger.LogInformation("Published point accrual: {TransactionId} for {CustomerId}", 
            message.TransactionId, message.CustomerId);
    }

    public async Task PublishBatchAsync(IEnumerable<PointAccrualMessage> messages, CancellationToken ct = default)
    {
        using var batch = await _sender.CreateMessageBatchAsync(ct);
        
        foreach (var message in messages)
        {
            var sbMessage = new ServiceBusMessage(JsonSerializer.SerializeToUtf8Bytes(message))
            {
                MessageId = message.TransactionId,
                ContentType = "application/json",
                Subject = message.TransactionType
            };

            if (!batch.TryAddMessage(sbMessage))
            {
                // Batch is full, send it and create a new one
                await _sender.SendMessagesAsync(batch, ct);
                _logger.LogInformation("Sent batch of {Count} point accruals", batch.Count);
            }
        }

        if (batch.Count > 0)
        {
            await _sender.SendMessagesAsync(batch, ct);
            _logger.LogInformation("Sent final batch of {Count} point accruals", batch.Count);
        }
    }

    public async ValueTask DisposeAsync()
    {
        await _sender.DisposeAsync();
    }
}

public interface IPointRedemptionPublisher
{
    Task PublishAsync(PointRedemptionMessage message, CancellationToken ct = default);
}

public class PointRedemptionPublisher : IPointRedemptionPublisher, IAsyncDisposable
{
    private readonly ServiceBusSender _sender;
    private readonly ILogger<PointRedemptionPublisher> _logger;

    public PointRedemptionPublisher(
        ServiceBusClient client,
        IOptions<ServiceBusOptions> options,
        ILogger<PointRedemptionPublisher> logger)
    {
        _sender = client.CreateSender(options.Value.Queues.PointRedemptions.QueueName);
        _logger = logger;
    }

    public async Task PublishAsync(PointRedemptionMessage message, CancellationToken ct = default)
    {
        var sbMessage = new ServiceBusMessage(JsonSerializer.SerializeToUtf8Bytes(message))
        {
            MessageId = message.RedemptionId,
            SessionId = message.CustomerId, // FIFO per customer
            ContentType = "application/json",
            ApplicationProperties =
            {
                ["CustomerId"] = message.CustomerId,
                ["Points"] = message.Points,
                ["RewardId"] = message.RewardId
            }
        };

        await _sender.SendMessageAsync(sbMessage, ct);
        _logger.LogInformation("Published point redemption: {RedemptionId} for {CustomerId}", 
            message.RedemptionId, message.CustomerId);
    }

    public async ValueTask DisposeAsync()
    {
        await _sender.DisposeAsync();
    }
}

public interface ILoyaltyEventPublisher
{
    Task PublishAsync(LoyaltyEvent @event, CancellationToken ct = default);
}

public class LoyaltyEventPublisher : ILoyaltyEventPublisher, IAsyncDisposable
{
    private readonly ServiceBusSender _sender;
    private readonly ILogger<LoyaltyEventPublisher> _logger;

    public LoyaltyEventPublisher(
        ServiceBusClient client,
        IOptions<ServiceBusOptions> options,
        ILogger<LoyaltyEventPublisher> logger)
    {
        _sender = client.CreateSender(options.Value.Topics.LoyaltyEvents.TopicName);
        _logger = logger;
    }

    public async Task PublishAsync(LoyaltyEvent @event, CancellationToken ct = default)
    {
        var sbMessage = new ServiceBusMessage(JsonSerializer.SerializeToUtf8Bytes(@event))
        {
            MessageId = Guid.NewGuid().ToString(),
            ContentType = "application/json",
            Subject = @event.EventType,
            ApplicationProperties =
            {
                ["EventType"] = @event.EventType,
                ["CustomerId"] = @event.CustomerId,
                ["PointValue"] = @event.PointValue ?? 0
            }
        };

        await _sender.SendMessageAsync(sbMessage, ct);
        _logger.LogInformation("Published loyalty event: {EventType} for {CustomerId}", 
            @event.EventType, @event.CustomerId);
    }

    public async ValueTask DisposeAsync()
    {
        await _sender.DisposeAsync();
    }
}

// ============================================
// Processors (Worker Services)
// ============================================

public class PointAccrualProcessor : BackgroundService
{
    private readonly ServiceBusProcessor _processor;
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<PointAccrualProcessor> _logger;

    public PointAccrualProcessor(
        ServiceBusClient client,
        IOptions<ServiceBusOptions> options,
        IServiceProvider serviceProvider,
        ILogger<PointAccrualProcessor> logger)
    {
        var queueOptions = options.Value.Queues.PointAccruals;
        _processor = client.CreateProcessor(queueOptions.QueueName, new ServiceBusProcessorOptions
        {
            MaxConcurrentCalls = queueOptions.MaxConcurrentCalls,
            PrefetchCount = queueOptions.PrefetchCount,
            AutoCompleteMessages = queueOptions.AutoCompleteMessages
        });
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _processor.ProcessMessageAsync += ProcessMessageAsync;
        _processor.ProcessErrorAsync += ProcessErrorAsync;

        await _processor.StartProcessingAsync(stoppingToken);

        // Keep running until stopped
        await Task.Delay(Timeout.Infinite, stoppingToken);
    }

    private async Task ProcessMessageAsync(ProcessMessageEventArgs args)
    {
        var message = JsonSerializer.Deserialize<PointAccrualMessage>(args.Message.Body.ToArray());
        if (message == null)
        {
            _logger.LogWarning("Failed to deserialize point accrual message");
            await args.DeadLetterMessageAsync(args.Message, "DeserializationFailed");
            return;
        }

        using var scope = _serviceProvider.CreateScope();
        var handler = scope.ServiceProvider.GetRequiredService<IPointAccrualHandler>();

        try
        {
            await handler.HandleAsync(message, args.CancellationToken);
            await args.CompleteMessageAsync(args.Message);
            _logger.LogInformation("Processed point accrual: {TransactionId}", message.TransactionId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing point accrual: {TransactionId}", message.TransactionId);
            // Let Service Bus handle retry/DLQ based on delivery count
            throw;
        }
    }

    private Task ProcessErrorAsync(ProcessErrorEventArgs args)
    {
        _logger.LogError(args.Exception, 
            "Service Bus error: {ErrorSource} - {FullyQualifiedNamespace}/{EntityPath}",
            args.ErrorSource, args.FullyQualifiedNamespace, args.EntityPath);
        return Task.CompletedTask;
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        await _processor.StopProcessingAsync(cancellationToken);
        await base.StopAsync(cancellationToken);
    }
}

// Session-enabled processor for redemptions (FIFO per customer)
public class PointRedemptionProcessor : BackgroundService
{
    private readonly ServiceBusSessionProcessor _processor;
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<PointRedemptionProcessor> _logger;

    public PointRedemptionProcessor(
        ServiceBusClient client,
        IOptions<ServiceBusOptions> options,
        IServiceProvider serviceProvider,
        ILogger<PointRedemptionProcessor> logger)
    {
        var queueOptions = options.Value.Queues.PointRedemptions;
        _processor = client.CreateSessionProcessor(queueOptions.QueueName, new ServiceBusSessionProcessorOptions
        {
            MaxConcurrentSessions = queueOptions.MaxConcurrentCalls,
            PrefetchCount = queueOptions.PrefetchCount,
            AutoCompleteMessages = queueOptions.AutoCompleteMessages
        });
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _processor.ProcessMessageAsync += ProcessMessageAsync;
        _processor.ProcessErrorAsync += ProcessErrorAsync;

        await _processor.StartProcessingAsync(stoppingToken);
        await Task.Delay(Timeout.Infinite, stoppingToken);
    }

    private async Task ProcessMessageAsync(ProcessSessionMessageEventArgs args)
    {
        var message = JsonSerializer.Deserialize<PointRedemptionMessage>(args.Message.Body.ToArray());
        if (message == null)
        {
            await args.DeadLetterMessageAsync(args.Message, "DeserializationFailed");
            return;
        }

        using var scope = _serviceProvider.CreateScope();
        var handler = scope.ServiceProvider.GetRequiredService<IPointRedemptionHandler>();

        try
        {
            await handler.HandleAsync(message, args.CancellationToken);
            await args.CompleteMessageAsync(args.Message);
            _logger.LogInformation("Processed point redemption: {RedemptionId} for session {SessionId}", 
                message.RedemptionId, args.SessionId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing point redemption: {RedemptionId}", message.RedemptionId);
            throw;
        }
    }

    private Task ProcessErrorAsync(ProcessErrorEventArgs args)
    {
        _logger.LogError(args.Exception, "Service Bus session error");
        return Task.CompletedTask;
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        await _processor.StopProcessingAsync(cancellationToken);
        await base.StopAsync(cancellationToken);
    }
}

public class TierCalculationProcessor : BackgroundService
{
    private readonly ServiceBusProcessor _processor;
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<TierCalculationProcessor> _logger;

    public TierCalculationProcessor(
        ServiceBusClient client,
        IOptions<ServiceBusOptions> options,
        IServiceProvider serviceProvider,
        ILogger<TierCalculationProcessor> logger)
    {
        var queueOptions = options.Value.Queues.TierCalculations;
        _processor = client.CreateProcessor(queueOptions.QueueName, new ServiceBusProcessorOptions
        {
            MaxConcurrentCalls = queueOptions.MaxConcurrentCalls,
            PrefetchCount = queueOptions.PrefetchCount,
            AutoCompleteMessages = queueOptions.AutoCompleteMessages
        });
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _processor.ProcessMessageAsync += ProcessMessageAsync;
        _processor.ProcessErrorAsync += ProcessErrorAsync;

        await _processor.StartProcessingAsync(stoppingToken);
        await Task.Delay(Timeout.Infinite, stoppingToken);
    }

    private async Task ProcessMessageAsync(ProcessMessageEventArgs args)
    {
        var message = JsonSerializer.Deserialize<TierCalculationMessage>(args.Message.Body.ToArray());
        if (message == null)
        {
            await args.DeadLetterMessageAsync(args.Message, "DeserializationFailed");
            return;
        }

        using var scope = _serviceProvider.CreateScope();
        var handler = scope.ServiceProvider.GetRequiredService<ITierCalculationHandler>();

        try
        {
            await handler.HandleAsync(message, args.CancellationToken);
            await args.CompleteMessageAsync(args.Message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing tier calculation for {CustomerId}", message.CustomerId);
            throw;
        }
    }

    private Task ProcessErrorAsync(ProcessErrorEventArgs args)
    {
        _logger.LogError(args.Exception, "Service Bus error in tier calculation");
        return Task.CompletedTask;
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        await _processor.StopProcessingAsync(cancellationToken);
        await base.StopAsync(cancellationToken);
    }
}

// Handler interfaces (implement in your service layer)
public interface IPointAccrualHandler
{
    Task HandleAsync(PointAccrualMessage message, CancellationToken ct = default);
}

public interface IPointRedemptionHandler
{
    Task HandleAsync(PointRedemptionMessage message, CancellationToken ct = default);
}

public interface ITierCalculationHandler
{
    Task HandleAsync(TierCalculationMessage message, CancellationToken ct = default);
}
