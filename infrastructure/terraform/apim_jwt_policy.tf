variable "b2c_api_client_id" { type = string description = "API app client id (audience) for API-level policy" }
locals { b2c_openid_config = "https://${var.b2c_domain}/${var.b2c_signin_policy}/v2.0/.well-known/openid-configuration"
         b2c_issuer        = "https://${var.b2c_domain}/${var.b2c_signin_policy}/v2.0/" }
resource "azurerm_api_management_api_policy" "gateway_api_jwt" {
  api_name            = azurerm_api_management_api.gateway_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  xml_content = <<POLICY
<policies>
  <inbound>
    <base />
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized" require-expiration-time="true" require-scheme="Bearer">
      <openid-config url="${local.b2c_openid_config}" />
      <audiences><audience>${var.b2c_api_client_id}</audience></audiences>
      <required-claims><claim name="iss"><value>${local.b2c_issuer}</value></claim></required-claims>
    </validate-jwt>
  </inbound><backend><base/></backend><outbound><base/></outbound><on-error><base/></on-error>
</policies>
POLICY
}
