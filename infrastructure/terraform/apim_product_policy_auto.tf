variable "b2c_domain"        { type = string }
variable "b2c_signin_policy" { type = string default = "B2C_1_signin" }
variable "apim_api_names"    { type = list(string) default = ["loyalty-gateway"] }
variable "audience_source"   { type = string default = "key_vault" }
variable "audience_secret_name" { type = string default = "b2c-api-client-id" }
variable "appconfig_name"    { type = string default = "" }
variable "appconfig_key"     { type = string default = "" }
variable "appconfig_label"   { type = string default = "" }
variable "audience_override" { type = string default = "" }

resource "azurerm_api_management_product" "loyalty_core" {
  product_id            = "loyalty-core"
  api_management_name   = azurerm_api_management.apim.name
  resource_group_name   = azurerm_resource_group.rg.name
  display_name          = "Loyalty Core"
  description           = "Core product with JWT enforcement for Bank Loyalty platform"
  published             = true
  subscription_required = false
  approval_required     = false
}

resource "azurerm_api_management_product_api" "attach_all" {
  for_each            = toset(var.apim_api_names)
  api_name            = each.value
  product_id          = azurerm_api_management_product.loyalty_core.product_id
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
}

data "azurerm_key_vault_secret" "aud_kv" {
  count        = var.audience_override != "" || var.audience_source != "key_vault" ? 0 : 1
  name         = var.audience_secret_name
  key_vault_id = azurerm_key_vault.kv.id
}

data "external" "aud_appconfig" {
  count   = var.audience_override != "" || var.audience_source != "app_config" ? 0 : 1
  program = ["bash", "${path.module}/scripts/get-appconfig-audience.sh", var.appconfig_name, var.appconfig_key, var.appconfig_label]
}

locals {
  b2c_openid_config = "https://${var.b2c_domain}/${var.b2c_signin_policy}/v2.0/.well-known/openid-configuration"
  b2c_issuer        = "https://${var.b2c_domain}/${var.b2c_signin_policy}/v2.0/"
  audience          = (
    var.audience_override != "" ? var.audience_override :
    var.audience_source == "app_config" ? try(data.external.aud_appconfig[0].result["audience"], "") :
    try(data.azurerm_key_vault_secret.aud_kv[0].value, "")
  )
}

resource "azurerm_api_management_product_policy" "jwt_b2c" {
  product_id          = azurerm_api_management_product.loyalty_core.product_id
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  xml_content = <<POLICY
<policies>
  <inbound>
    <base />
    <validate-jwt header-name="Authorization"
                  failed-validation-httpcode="401"
                  failed-validation-error-message="Unauthorized"
                  require-expiration-time="true"
                  require-scheme="Bearer">
      <openid-config url="${local.b2c_openid_config}" />
      <audiences>
        <audience>${local.audience}</audience>
        <audience>api://${local.audience}</audience>
      </audiences>
      <required-claims>
        <claim name="iss"><value>${local.b2c_issuer}</value></claim>
        <claim name="scp"><value>Loyalty.Read</value><value>Loyalty.Write</value></claim>
      </required-claims>
    </validate-jwt>
  </inbound>
  <backend><base /></backend>
  <outbound><base /></outbound>
  <on-error><base /></on-error>
</policies>
POLICY

  depends_on = [azurerm_api_management_product_api.attach_all]
}
