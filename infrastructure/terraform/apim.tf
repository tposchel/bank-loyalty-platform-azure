resource "azurerm_api_management" "apim" {
  name                = local.apim
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = "Bank Loyalty"
  publisher_email     = "devnull@example.com"
  sku_name            = "Developer_1"
  tags                = local.tags
}
variable "ingress_host" { type = string default = "loyalty.example.com" }
resource "azurerm_api_management_api" "gateway_api" {
  name                = "loyalty-gateway"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "Loyalty Gateway"
  path                = "loyalty"
  protocols           = ["https"]
  import { content_format = "swagger-link-json" content_value  = "https://${var.ingress_host}/swagger/v1/swagger.json" }
}
