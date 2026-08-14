# Contributing

This repository is a cost-conscious learning lab for Windows Server Failover
Clustering on Azure. Changes should keep the lab runnable end to end with a
single `terraform apply` followed by the documented drills.

## Ground rules

- Work on a branch and open a pull request to `main`.
- Keep modules small and focused; the root module owns orchestration order.
- Feature flags use `deploy_*` and `enable_*` names and default to the
  cheapest safe behavior.
- Explain cost, security, and compatibility impact in the pull request.
- Never include credentials, generated passwords, plan files, or state.
- CI is validation-only. Applies and destroys are always local and manual;
  do not add Azure credentials or OIDC tokens to workflows.

## Required checks

```powershell
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform test
tflint --init
tflint --recursive
trivy config --severity MEDIUM,HIGH,CRITICAL --ignorefile .trivyignore.yaml .
checkov -d . --config-file .checkov.yml
gitleaks detect --config .gitleaks.toml --source . --no-git --redact
```

Regenerate Terraform references after changing an input, output, provider,
resource, or module:

```powershell
./scripts/generate-terraform-docs.ps1
```

Generated `README.md` files under `modules/`, plus `TERRAFORM.md`, must be
committed with the source change.

## Guest and drill scripts

- Guest scripts (`scripts/vm/`) run through Azure run commands or extensions.
  They must be idempotent: re-running against a configured node exits 0
  without side effects.
- Guest scripts must not assume outbound internet access. New VNets have no
  default outbound connectivity; only the Azure host channel
  (168.63.129.16) and service-endpoint traffic are reachable.
- Drill scripts (`scripts/`) run from the workstation via `az` CLI. Join
  run-command output arrays before matching
  (`($result.value | ForEach-Object message) -join "`n"`).

## Security exceptions

Do not add a global scanner skip to make CI green. Add only a scoped,
time-bounded exception, document its rationale and compensating control in
`SECURITY_EXCEPTIONS.md`, and set a review date.
