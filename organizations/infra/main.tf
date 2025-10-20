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
module "control_repository" {
  for_each = local.org_configs
  providers = {
    github = github.${each.key}
  }
}


# Define the variables this workspace will consume from its auto.tfvars files
variable "mac_mini_runner_allowed_repos" { type = list(string) }
variable "github_apps" { type = map(any) }
variable "additional_vault_policies" { type = list(string) }
