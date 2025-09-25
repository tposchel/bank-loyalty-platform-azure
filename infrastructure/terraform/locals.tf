locals {
  base    = "${var.prefix}-${var.environment}"
  rg_name = "${local.base}-rg"
  vnet    = "${local.base}-vnet"
  aks_sub = "${local.base}-aks-subnet"
  acr     = "${local.base}acr"
  aks     = "${local.base}-aks"
  kv      = "${local.base}-kv"
  appcfg  = "${local.base}-appcfg"
  sqlsvr  = replace("${local.base}-sql", "-", "")
  la_name = "${local.base}-law"
  ai_name = "${local.base}-appi"
  cosmos  = "${local.base}-cosmos"
  redis   = "${local.base}-redis"
  apim    = "${local.base}-apim"
  tags    = merge(var.tags, { env = var.environment, component = "bank-loyalty" })
}
