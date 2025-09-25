# Bank Loyalty Platform – Full ADO-ready repo

One-stop, enterprise scaffold:
- **Infra (Terraform):** AKS (OIDC + CSI-KeyVault), ACR, SQL (+DBs), Cosmos (serverless), Redis, Key Vault (RBAC), App Configuration,
  Private Endpoints + Private DNS, APIM, UAMI + FICs, **B2C user flow** via Graph.
- **APIM policies:** **Product-level JWT** (B2C) with audience from **Key Vault** or **App Config KV reference**; example API-level policy.
- **Kubernetes:** Helm chart with **Workload Identity** + **Key Vault CSI**; **App Configuration Kubernetes Provider** manifests.
- **Apps:** Gateway (YARP) + sample .NET 8 APIs with **Microsoft.Identity.Web**; **React (MSAL)** and **Blazor** with **OBO**.
- **Pipelines:** Multi-stage **Terraform + Helm** with approvals; **Teams notifications** variant; simple app build.

See `docs/HOWTO.md` for end-to-end steps.
