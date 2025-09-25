variable "prefix"          { type = string }
variable "environment"     { type = string }
variable "location"        { type = string  default = "eastus" }
variable "tags"            { type = map(string) default = {} }

variable "address_space"   { type = list(string) default = ["10.60.0.0/16"] }
variable "aks_subnet_cidr" { type = string default = "10.60.1.0/24" }
variable "aks_node_count"  { type = number default = 3 }
variable "aks_node_size"   { type = string  default = "Standard_DS3_v2" }
variable "acr_sku"         { type = string  default = "Standard" }

variable "sql_admin_login"    { type = string }
variable "sql_admin_password" { type = string  sensitive = true }

# B2C
variable "b2c_tenant_id"     { type = string }
variable "b2c_domain"        { type = string }
variable "b2c_signin_policy" { type = string default = "B2C_1_signin" }

variable "image_registry"  { type = string  default = "myacr.azurecr.io" }
variable "image_tag"       { type = string  default = "latest" }

variable "kube_namespace" { type = string default = "loyalty-dev" }
