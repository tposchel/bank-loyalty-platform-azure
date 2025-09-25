variable "b2c_userflow_id" { type = string default = "B2C_1_signin" }
resource "null_resource" "b2c_userflow" {
  triggers = { id = var.b2c_userflow_id, tenant = var.b2c_tenant_id, domain = var.b2c_domain }
  provisioner "local-exec" {
    interpreter = ["bash", "-lc"]
    command = <<'EOT'
set -euo pipefail
UF="${var.b2c_userflow_id}"
az rest --method GET --url "https://graph.microsoft.com/v1.0/identity/b2cUserFlows/${var.b2c_userflow_id}" --only-show-errors >/dev/null 2>&1 || az rest --method POST --url https://graph.microsoft.com/v1.0/identity/b2cUserFlows --body '{
  "id": "'"$UF"'",
  "userFlowType": "signUpOrSignIn",
  "userFlowTypeVersion": 1
}'
attr=$(az rest --method GET --url https://graph.microsoft.com/v1.0/identity/userFlowAttributes/tenantId --only-show-errors || true)
if [[ -z "$attr" ]]; then
  az rest --method POST --url https://graph.microsoft.com/v1.0/identity/userFlowAttributes --body '{
    "displayName": "tenantId",
    "description": "Tenant identifier",
    "dataType": "string",
    "userFlowAttributeType": "custom"
  }'
fi
attrId=$(az rest --method GET --url https://graph.microsoft.com/v1.0/identity/userFlowAttributes --query "value[?displayName=='tenantId'].id" -o tsv)
assigns=$(az rest --method GET --url https://graph.microsoft.com/v1.0/identity/b2cUserFlows/${var.b2c_userflow_id}/userAttributeAssignments)
echo "$assigns" | grep -q "$attrId" || az rest --method POST --url https://graph.microsoft.com/v1.0/identity/b2cUserFlows/${var.b2c_userflow_id}/userAttributeAssignments --body "{
  \"userAttribute@odata.bind\": \"https://graph.microsoft.com/v1.0/identity/userFlowAttributes/${attrId}\",
  \"isOptional\": true,
  \"requiresVerification\": false
}"
EOT
  }
}
