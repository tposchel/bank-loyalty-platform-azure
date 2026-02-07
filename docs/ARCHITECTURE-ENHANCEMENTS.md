# Architecture Enhancements

This document describes the recommended architecture enhancements for the Bank Loyalty Platform.

## Overview

The following changes address gaps identified in the original architecture:

| Gap | Solution | Priority |
|-----|----------|----------|
| No observability | Application Insights + OpenTelemetry | Critical |
| No disaster recovery | Geo-replicated SQL, multi-region Cosmos, Traffic Manager | High |
| No event-driven architecture | Azure Service Bus with queues and topics | High |
| No WAF/DDoS protection | Azure Front Door Premium with WAF | High |
| No compliance guardrails | Azure Policy + Defender for Cloud | Medium |

## New Modules

### 1. Monitoring (`modules/monitoring`)

Comprehensive observability stack:

- **Log Analytics Workspace**: Centralized logging with 90-day retention
- **Application Insights**: APM with distributed tracing
- **Smart Detection**: Anomaly detection for failures and degradation
- **Custom Alerts**: Error rate, response time, dependency failures
- **Log-based Alerts**: Failed redemptions, unusual accrual patterns (fraud)
- **Availability Tests**: Multi-region health monitoring
- **Workbooks**: Pre-built loyalty platform dashboard
- **Container Insights**: AKS monitoring

**Usage:**
```hcl
module "monitoring" {
  source = "./modules/monitoring"
  
  prefix              = var.prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  
  critical_alert_emails = [
    { name = "On-Call", email = "oncall@example.com" }
  ]
  
  health_check_url = "https://api.example.com/health"
}
```

### 2. Front Door (`modules/frontdoor`)

Global load balancing with WAF:

- **Azure Front Door Premium**: Global HTTP load balancer
- **WAF Policy**: OWASP 3.2 rules + bot protection
- **Rate Limiting**: Configurable per-endpoint limits (default: 10 redemptions/min/IP)
- **Geo-blocking**: Optional country-level blocking
- **Private Link**: Secure connectivity to APIM
- **Diagnostics**: Full WAF and access logs to Log Analytics

**Usage:**
```hcl
module "frontdoor" {
  source = "./modules/frontdoor"
  
  prefix                = var.prefix
  waf_mode              = "Prevention"
  redemption_rate_limit = 10
  blocked_countries     = ["KP", "IR"]  # Optional
  
  apim_primary_hostname = azurerm_api_management.main.gateway_url
  apim_primary_id       = azurerm_api_management.main.id
}
```

### 3. Service Bus (`modules/servicebus`)

Async messaging for loyalty operations:

**Queues:**
- `point-accruals`: High-volume, partitioned, duplicate detection
- `point-redemptions`: Session-enabled for FIFO per customer
- `tier-calculations`: Batch processing
- `dlq-reprocess`: Dead letter reprocessing

**Topics:**
- `loyalty-events`: Pub/sub with subscriptions for notifications, analytics, fraud detection

**Features:**
- Private endpoint (no public access)
- AAD-only authentication (no SAS keys)
- Workload Identity integration
- DLQ alerts

**Usage:**
```hcl
module "servicebus" {
  source = "./modules/servicebus"
  
  prefix   = var.prefix
  sku      = "Premium"
  capacity = 1
  
  aks_workload_identity_principal_id = azurerm_user_assigned_identity.aks.principal_id
}
```

### 4. Disaster Recovery (`modules/disaster-recovery`)

Multi-region resilience:

- **SQL Failover Group**: Automatic failover with 60-minute grace period
- **Cosmos Multi-Region**: Configurable active-passive or active-active
- **Redis Geo-Replication**: Secondary replica (Premium tier)
- **Traffic Manager**: Priority-based routing to APIM

**Usage:**
```hcl
module "disaster_recovery" {
  source = "./modules/disaster-recovery"
  
  primary_location   = "eastus"
  secondary_location = "westus2"
  
  primary_sql_server_id = azurerm_mssql_server.main.id
  database_ids          = [azurerm_mssql_database.loyalty.id]
  
  traffic_routing_method = "Priority"
}
```

### 5. Azure Policy (`modules/azure-policy`)

Compliance guardrails:

- **Custom Policies**: TLS 1.2 enforcement, private endpoints, CMK encryption
- **Policy Initiative**: Combined security baseline
- **Defender for Cloud**: All relevant resource types enabled
- **Security Contacts**: Automated alert routing

**Usage:**
```hcl
module "azure_policy" {
  source = "./modules/azure-policy"
  
  subscription_id        = data.azurerm_client_config.current.subscription_id
  environment            = "prod"
  private_endpoint_effect = "Deny"  # Audit in non-prod
  
  security_contact_email = "security@example.com"
}
```

## Application Changes

### Observability Integration

Add to your .NET services:

```csharp
// Program.cs
builder.Services.AddLoyaltyObservability(builder.Configuration, builder.Environment);
```

This enables:
- Application Insights with OpenTelemetry
- W3C Trace Context propagation
- Custom telemetry initializer (adds customer ID, correlation ID)
- Health checks for all dependencies

### Service Bus Integration

**Publishing messages:**
```csharp
builder.Services.AddLoyaltyServiceBus(builder.Configuration);

// In your service:
public class PointsService
{
    private readonly IPointAccrualPublisher _publisher;
    
    public async Task AccruePointsAsync(string customerId, int points)
    {
        // Synchronous validation...
        
        // Async processing
        await _publisher.PublishAsync(new PointAccrualMessage(
            customerId, points, Guid.NewGuid().ToString(), "Purchase", DateTimeOffset.UtcNow));
    }
}
```

**Processing messages (worker service):**
```csharp
builder.Services.AddLoyaltyServiceBusProcessors(builder.Configuration);
builder.Services.AddScoped<IPointAccrualHandler, PointAccrualHandler>();
```

### Health Check Endpoints

The following endpoints are exposed:

| Endpoint | Purpose | Checks |
|----------|---------|--------|
| `/health/live` | Liveness probe | None (is process running?) |
| `/health/ready` | Readiness probe | All dependencies |
| `/health/startup` | Startup probe | All dependencies |
| `/metrics` | Prometheus scraping | N/A |

## Helm Changes

Merge `values-enhancements.yaml` with your existing values:

```bash
helm upgrade --install loyalty ./helm/microplatform \
  -f values.yaml \
  -f values-enhancements.yaml
```

Key additions:
- `observability`: Application Insights configuration
- `serviceBus`: Queue/topic configuration
- `healthChecks`: Probe paths and dependency checks
- `metrics`: Prometheus exporter settings
- `autoscaling`: KEDA scalers for Service Bus queue depth

## Migration Steps

1. **Apply Terraform changes:**
   ```bash
   cd infrastructure/terraform
   terraform init
   terraform plan -out=plan.tfplan
   terraform apply plan.tfplan
   ```

2. **Update application configuration:**
   - Add Application Insights connection string to Key Vault
   - Add Service Bus namespace to App Configuration
   - Update `appsettings.json` with health check and Service Bus settings

3. **Deploy application updates:**
   ```bash
   helm upgrade loyalty ./helm/microplatform -f values-enhancements.yaml
   ```

4. **Verify:**
   - Check Application Insights for traces
   - Verify health endpoints return 200
   - Test Service Bus message flow
   - Confirm WAF is in Detection mode before switching to Prevention

## Cost Considerations

| Component | SKU | Estimated Monthly Cost |
|-----------|-----|----------------------|
| Front Door Premium | Per request + WAF | $35 + usage |
| Service Bus Premium | 1 MU | ~$700 |
| Log Analytics | Per GB | ~$2.30/GB |
| Application Insights | Per GB | Included in Log Analytics |
| Traffic Manager | Per million queries | ~$0.75/M |
| Defender for Cloud | Per resource type | Varies |

**Cost optimization:**
- Use Service Bus Standard in non-prod ($10/month base)
- Reduce Log Analytics retention in non-prod
- Start with WAF in Detection mode (same cost, lower risk)

## Security Considerations

1. **All data services use private endpoints** - no public internet exposure
2. **Service Bus uses AAD-only authentication** - no SAS keys
3. **WAF blocks OWASP top 10 + bots** - adjust rules as needed
4. **Defender for Cloud enabled** - continuous compliance monitoring
5. **TLS 1.2 enforced everywhere** - policy prevents downgrade

## Tradeoffs Addressed

| Original Tradeoff | Resolution |
|-------------------|------------|
| Cosmos serverless RU limits | Use provisioned throughput with autoscale for prod |
| YARP + APIM redundancy | Keep YARP for BFF aggregation; APIM for external exposure |
| Single Helm chart | Split if teams need independent releases; umbrella for dev |
| B2C Graph API fragility | Accept; add retry logic and alerting on pipeline failures |
