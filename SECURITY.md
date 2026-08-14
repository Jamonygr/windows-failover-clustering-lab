# Security policy

## Reporting a vulnerability

Use the repository's private GitHub security-advisory reporting flow. Do not
open a public issue containing credentials, tenant information, exploit
steps, state, or plan output. Include the affected path, impact, reproduction
steps, and a proposed mitigation when possible.

## Supported scope

Security fixes target the current `main` branch. This repository is a
learning lab and does not provide a production support or compliance
guarantee.

## Secret handling

- Supply Terraform secrets through ephemeral `TF_VAR_*` environment variables
  (`TF_VAR_admin_password`, `TF_VAR_safe_mode_password`) or let Terraform
  generate them; retrieve generated values only through sensitive outputs.
- Never commit `.tfvars` containing credentials, `.tfstate`, saved plans, or
  storage keys.
- The Cloud Witness storage key and domain credentials transit only through
  run-command protected parameters and a temporary ACL-restricted file on the
  node that is deleted after configuration (see `SECURITY_EXCEPTIONS.md`).
- If a value may have been exposed, rotate it before attempting to remove it
  from history. Rotate the witness storage key and VM passwords before
  publishing anything captured from a live run.

CI never authenticates to Azure. The blocking scanners are Trivy, Checkov,
Gitleaks, and TFLint. Accepted lab-only risks are listed in
`SECURITY_EXCEPTIONS.md` with expiry dates.
