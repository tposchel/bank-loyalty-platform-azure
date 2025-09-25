# HOWTO – End to End

1) `az login` to your Azure subscription (and to **B2C tenant** before running Graph steps).
2) Terraform:
   ```bash
   cd infrastructure/terraform
   terraform init
   terraform apply -var-file=env/dev.tfvars
   ```
3) Helm:
   ```bash
   helm upgrade --install microplatform helm/microplatform -n loyalty-dev --create-namespace
   ```
4) APIM product-level JWT policy: audience from Key Vault or App Config (KV ref) based on tfvars.
5) React/Blazor env: supply B2C IDs via Key Vault secrets (synced by CSI) and set `values.yaml` appropriately.
6) Pipelines: use `azure-pipelines-infra.yml` (or the Teams variant) in Azure DevOps with Environments `dev/qa/prod`.
