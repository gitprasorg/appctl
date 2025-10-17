# organizations/gitprasorg-prod/main.tf

# Configure the GitHub provider for this specific organization/workspace
provider "github" {
  # token = var.github_token_for_prod
}

# Configure the Vault provider for this specific organization/workspace
provider "vault" {
  # ... configuration ...
}

# Call the reusable logic module
module "ABCD_control_config" {
  source = "../../modules/github-control-logic"

  # Pass static variables
  organization_name = "gitprasorg-prod"
  apm_code          = "ABCD"

  # Pass variables loaded from ABCD.auto.tfvars
  mac_mini_runner_allowed_repos = var.mac_mini_runner_allowed_repos
  github_apps                   = var.github_apps
  additional_vault_policies     = var.additional_vault_policies
}

# Define the variables this workspace will consume from its auto.tfvars files
variable "mac_mini_runner_allowed_repos" { type = list(string) }
variable "github_apps" { type = map(any) }
variable "additional_vault_policies" { type = list(string) }
