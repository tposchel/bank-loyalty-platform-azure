# Azure Policy for Banking/Financial Services Compliance
# Enforces security baselines and regulatory requirements

# ============================================
# Policy Definitions (Custom)
# ============================================

# Require TLS 1.2 minimum on all supported resources
resource "azurerm_policy_definition" "require_tls_12" {
  name         = "require-tls-1-2"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Require TLS 1.2 or higher"
  description  = "Ensures all resources use TLS 1.2 or higher for secure communications"

  metadata = jsonencode({
    category = "Security"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      anyOf = [
        {
          allOf = [
            { field = "type", equals = "Microsoft.Storage/storageAccounts" },
            { field = "Microsoft.Storage/storageAccounts/minimumTlsVersion", notEquals = "TLS1_2" }
          ]
        },
        {
          allOf = [
            { field = "type", equals = "Microsoft.Sql/servers" },
            { field = "Microsoft.Sql/servers/minimalTlsVersion", notEquals = "1.2" }
          ]
        },
        {
          allOf = [
            { field = "type", equals = "Microsoft.Cache/redis" },
            { field = "Microsoft.Cache/redis/minimumTlsVersion", notEquals = "1.2" }
          ]
        }
      ]
    }
    then = {
      effect = "deny"
    }
  })
}

# Require private endpoints for data services
resource "azurerm_policy_definition" "require_private_endpoints" {
  name         = "require-private-endpoints"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Require private endpoints for data services"
  description  = "Ensures data services use private endpoints"

  metadata = jsonencode({
    category = "Network"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field = "type"
          in = [
            "Microsoft.Storage/storageAccounts",
            "Microsoft.Sql/servers",
            "Microsoft.DocumentDB/databaseAccounts",
            "Microsoft.Cache/redis",
            "Microsoft.KeyVault/vaults",
            "Microsoft.ServiceBus/namespaces"
          ]
        },
        { field = "[concat('Microsoft.', field('type'), '/publicNetworkAccess')]", notEquals = "Disabled" }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })

  parameters = jsonencode({
    effect = {
      type          = "String"
      defaultValue  = "Audit"
      allowedValues = ["Audit", "Deny", "Disabled"]
      metadata = {
        displayName = "Effect"
        description = "The effect determines what happens when the policy rule is evaluated to true"
      }
    }
  })
}

# Require encryption at rest with CMK
resource "azurerm_policy_definition" "require_cmk_encryption" {
  name         = "require-cmk-encryption"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Require customer-managed keys for encryption"
  description  = "Ensures data at rest is encrypted with customer-managed keys"

  metadata = jsonencode({
    category = "Encryption"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", equals = "Microsoft.Storage/storageAccounts" },
        { field = "Microsoft.Storage/storageAccounts/encryption.keySource", notEquals = "Microsoft.Keyvault" }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })

  parameters = jsonencode({
    effect = {
      type          = "String"
      defaultValue  = "Audit"
      allowedValues = ["Audit", "Deny", "Disabled"]
    }
  })
}

# ============================================
# Policy Initiative (Policy Set)
# ============================================

resource "azurerm_policy_set_definition" "loyalty_platform_baseline" {
  name         = "loyalty-platform-security-baseline"
  policy_type  = "Custom"
  display_name = "Loyalty Platform Security Baseline"
  description  = "Security and compliance baseline for bank loyalty platform"

  metadata = jsonencode({
    category = "Regulatory Compliance"
    version  = "1.0.0"
  })

  # Custom policies
  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.require_tls_12.id
    reference_id         = "RequireTLS12"
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.require_private_endpoints.id
    reference_id         = "RequirePrivateEndpoints"
    parameter_values = jsonencode({
      effect = { value = var.private_endpoint_effect }
    })
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.require_cmk_encryption.id
    reference_id         = "RequireCMKEncryption"
    parameter_values = jsonencode({
      effect = { value = var.cmk_encryption_effect }
    })
  }

  # Built-in policies
  # Azure Security Benchmark
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0961003e-5a0a-4549-abde-af6a37f2724d"
    reference_id         = "AKSAzurePolicy"
  }

  # Key Vault should use RBAC
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/12d4fa5e-1f9f-4c21-97a9-b99b3c6611b5"
    reference_id         = "KeyVaultRBAC"
  }

  # SQL servers should use private endpoints
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/7698e800-9299-47a6-b3b6-5a0fee576ebb"
    reference_id         = "SQLPrivateEndpoint"
  }

  # Managed identity should be used
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e3f92a0b-5d7e-4f1e-8c8b-77a85c76f9f5"
    reference_id         = "RequireManagedIdentity"
  }

  # Azure Defender for SQL
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/6581d072-105e-4418-827f-bd446d56421b"
    reference_id         = "DefenderForSQL"
  }

  # Diagnostic settings should be enabled
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/7f89b1eb-583c-429a-8828-af049802c1d9"
    reference_id         = "DiagnosticSettings"
  }
}

# ============================================
# Policy Assignments
# ============================================

resource "azurerm_subscription_policy_assignment" "loyalty_baseline" {
  count                = var.assign_at_subscription ? 1 : 0
  name                 = "loyalty-baseline"
  policy_definition_id = azurerm_policy_set_definition.loyalty_platform_baseline.id
  subscription_id      = var.subscription_id
  display_name         = "Loyalty Platform Security Baseline"
  description          = "Enforces security baseline for loyalty platform"
  location             = var.location

  identity {
    type = "SystemAssigned"
  }

  non_compliance_message {
    content = "This resource does not comply with the Loyalty Platform security baseline. Please review the policy requirements."
  }

  metadata = jsonencode({
    assignedBy = "Terraform"
    environment = var.environment
  })
}

resource "azurerm_resource_group_policy_assignment" "loyalty_baseline_rg" {
  count                = var.assign_at_subscription ? 0 : 1
  name                 = "loyalty-baseline-rg"
  policy_definition_id = azurerm_policy_set_definition.loyalty_platform_baseline.id
  resource_group_id    = var.resource_group_id
  display_name         = "Loyalty Platform Security Baseline"
  description          = "Enforces security baseline for loyalty platform"
  location             = var.location

  identity {
    type = "SystemAssigned"
  }

  non_compliance_message {
    content = "This resource does not comply with the Loyalty Platform security baseline. Please review the policy requirements."
  }
}

# ============================================
# Defender for Cloud
# ============================================

resource "azurerm_security_center_subscription_pricing" "defender_servers" {
  tier          = "Standard"
  resource_type = "VirtualMachines"
}

resource "azurerm_security_center_subscription_pricing" "defender_sql" {
  tier          = "Standard"
  resource_type = "SqlServers"
}

resource "azurerm_security_center_subscription_pricing" "defender_storage" {
  tier          = "Standard"
  resource_type = "StorageAccounts"
}

resource "azurerm_security_center_subscription_pricing" "defender_containers" {
  tier          = "Standard"
  resource_type = "Containers"
}

resource "azurerm_security_center_subscription_pricing" "defender_keyvault" {
  tier          = "Standard"
  resource_type = "KeyVaults"
}

resource "azurerm_security_center_subscription_pricing" "defender_arm" {
  tier          = "Standard"
  resource_type = "Arm"
}

resource "azurerm_security_center_subscription_pricing" "defender_dns" {
  tier          = "Standard"
  resource_type = "Dns"
}

resource "azurerm_security_center_subscription_pricing" "defender_cosmos" {
  tier          = "Standard"
  resource_type = "CosmosDbs"
}

# Auto-provisioning for Log Analytics agent
resource "azurerm_security_center_auto_provisioning" "auto_provision" {
  auto_provision = "On"
}

# Security contacts
resource "azurerm_security_center_contact" "security_contact" {
  email               = var.security_contact_email
  phone               = var.security_contact_phone
  alert_notifications = true
  alerts_to_admins    = true
}

# ============================================
# Compliance Dashboard Export
# ============================================

resource "azurerm_security_center_assessment_policy" "loyalty_custom" {
  display_name = "Loyalty Platform Custom Assessment"
  description  = "Custom security assessment for loyalty platform compliance"
  severity     = "High"
}
