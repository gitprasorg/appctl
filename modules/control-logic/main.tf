# modules/github-control-logic/main.tf

# -----------------------------------------------------------------------------
# 1. MAC MINI RUNNER GROUP WHITELISTING
# -----------------------------------------------------------------------------

# Data source to fetch the repository IDs for all allowed repos
data "github_repository" "mac_mini_allowed" {
  for_each = toset(var.mac_mini_runner_allowed_repos)
  name     = each.key
  # The provider is inherited from the calling organization/workspace
}

# Resource to update the runner group access list
resource "github_actions_runner_group" "mac_mini" {
  # The provider is inherited from the calling organization/workspace
  name       = "mac-mini-runnergrp"
  visibility = "selected"

  # Collect the IDs of all allowed repositories
  selected_repository_ids = [for r in data.github_repository.mac_mini_allowed : r.id]
}

# -----------------------------------------------------------------------------
# 2. GITHUB APP INSTALLATION REPOSITORY ATTACHMENT
# -----------------------------------------------------------------------------

# Flatten the structure to map (app_key:repo_name) -> { installation_id, repository }
locals {
  github_app_repo_pairs = {
    for pair in flatten([
      for app_key, app in var.github_apps : [
        for repo_name in app.repositories : {
          key             = "${app_key}:${repo_name}"
          installation_id = app.installation_id
          repository      = repo_name
        }
      ]
    ]) : pair.key => pair
  }
}

resource "github_app_installation_repository" "attach" {
  for_each        = local.github_app_repo_pairs
  installation_id = each.value.installation_id
  repository      = each.value.repository
  # The provider is inherited from the calling organization/workspace
}

# -----------------------------------------------------------------------------
# 3. VAULT POLICY INJECTION (CALLS YOUR UPLOADED VAULT MODULE)
# -----------------------------------------------------------------------------

module "vault_jwt_role" {
  # Assuming your uploaded vault module is at '../vault-jwt-role' relative to this module
  for_each = local.github_app_repo_pairs 
  source   = "../vault-jwt-role"

  object_name         = each.value.repository
  organization        = var.organization_name
  environment         = "uat" # Default environment, adjust as needed
  context             = "build"
  epm_code            = var.apm_code
  platform            = "ghec"

  # Inject the policies from the APM.auto.tfvars file
  additional_policies = var.additional_vault_policies 
}
