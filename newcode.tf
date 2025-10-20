##objective
# Current repo is configured by VCSW configuration within terraform cloud workspace and is intended to be used as a control repository . Currently this control repo vcs workspace is in sandbox org, eventually it will be cloned/forked to prod org so that repositories and apps in that org context can be managed using terraform .

# Currently there are 4 orgs  in the enterpise 
# infra, shared, sandbox. prod
# Multiple application codes (e.g., bjgs, abcd, bfb8, bjtn, etc.)
# The control repos purpose:

# Centrally manage which app repos (e.g., bjgs, abcd, …) can use the mac-minis self-hosted runner group.

# Manage which GitHub Apps are allowed per org.

# Keep the Vault authentication setup to dynamically provide GitHub credentials for Terraform.

# Support multiple apps per org, without duplicating code.

# Each org has its own folder in orgs/.

# Each app code has a .auto.tfvars inside the org’s folder.

# Terraform will loop through:
# all app codes per org
# and apply rules for runners + GitHub Apps.

# Facts:
# 1. each org will have its own runner group named 'mac-minis'. In the future there is a possibility to have more runner groups per org.
# 2. each org will have its own allowed GitHub Apps list.
# This repo should inherit the org owner from the current context (e.g., via GitHub provider configuration).
# There is no need to create orgs, repos, or GitHub Apps here or runner groups. However existing runner groups, apps will need to be referred based on runner group name and app installation ID, this may need to be imported into the state file . 

# repository layout
# ; root/
# ; ├── main.tf
# ; ├── providers.tf
# ; ├── versions.tf
# ; ├── variables.tf
# ; ├── outputs.tf
# ; ├── vault/
# ; │   ├── main.tf     # keep your existing Vault setup from ZIP here
# ; │   ├── variables.tf
# ; │   └── outputs.tf
# ; ├── modules/
# ; │   ├── control_repository/
# ; │   │   ├── main.tf
# ; │   │   ├── variables.tf
# ; │   │   ├── outputs.tf
# ; │   │   └── ...
# ; │   └── jwt-role/   # your Vault integration stays here untouched
# ; │       ├── main.tf
# ; │       └── ...
# ; ├── orgs/
# ; |   |-sanbox/
# ; │       ├── main.tf
# ; │       ├── bjgs.auto.tfvars
# ; │       ├── abcd.auto.tfvars
# ; │       ├── efgh.auto.tfvars
# ; │       └── ijkl.auto.tfvars
# ; |   |-prod/
# ; │       ├── main.tf
# ; │       ├── bjgs.auto.tfvars
# ; │       ├── abcd.auto.tfvars
# ; │       ├── efgh.auto.tfvars
# ; │       └── ijkl.auto.tfvars


#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;#

#bjgs.auto.tfvars
# must be json compatible format
apm_code = "bjgs"
org_name = "sandbox" 

macmini_allowed_repositories = [
  "ios-build",
  "swift-ci",
]

allowed_github_apps = [
  "mobile-ci-app",
  "xccloud-sync"
]

#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;#

#/root/variables.tf 
variable "org_apps" {
  description = "Map of application configurations within the org"
  type = map(object({
    apm_code                    = string
    macmini_allowed_repositories = list(string)
    allowed_github_apps         = list(string)
  }))
}
#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;#
#root/vesions.tf
terraform {
  required_version = ">= 1.8"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    terraform = {
      source  = "terraform.io/builtin/terraform"
      version = "~> 1.8"
    }
  }
}
#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;#

#root/main.tf
# locals {
#   org_configs = { for f in fileset("${path.module}/orgs", "*.auto.tfvars") :
#     replace(basename(f), ".auto.tfvars", "") => terraform.tfvars_decode(file("${path.module}/orgs/${f}"))
#   }

locals {
  org_dirs = fileset("${path.module}/orgs", "*")
  org_configs = {
    for org in local.org_dirs : org => {
      apps = {
        for f in fileset("${path.module}/orgs/${org}", "*.auto.tfvars") :
        replace(basename(f), ".auto.tfvars", "") =>
        jsondecode(file("${path.module}/orgs/${org}/${f}"))
      }
    }
  }
  org_provider_map = {
    infra   = github.infra
    shared  = github.shared
    sandbox = github.sandbox
    prod    = github.prod
  }
}

# Apply control_repository module per org
# Loop over each org, apply control_repository module
module "control_repository" {
  for_each = local.org_configs
  source   = "./modules/control_repository"

  providers = {
    github = local.org_provider_map[each.key]
    vault  = vault
  }

  apm_code                    = null  # each.value.apm_code
  org_name                    = each.key
  org_apps                    = each.value.apps 
  # macmini_allowed_repositories = each.value.macmini_allowed_repositories
  # allowed_github_apps         = each.value.allowed_github_apps
  macmini_allowed_repositories = flatten([for app in values(each.value.apps) : app.macmini_allowed_repositories])
allowed_github_apps         = flatten([for app in values(each.value.apps) : app.allowed_github_apps])
  vault_address               = var.vault_address
  vault_namespace             = var.vault_namespace
}

locals {
  apps = var.org_apps
}

# Loop over apps
module "per_app" {
  for_each = var.org_apps
  source   = "../modules/control_repository_per_app"  
  org_name                    = var.org_name
  apm_code                    = each.value.apm_code
  macmini_allowed_repositories = each.value.macmini_allowed_repositories
  allowed_github_apps         = each.value.allowed_github_apps

  providers = {
    github = github  # inherit current github provider alias
  }
}

#root/providers.tf

# The default provider will be used unless an alias is specified in a resource/module.
# We will define all four for explicit use.

provider "github" {
  alias = "prod"
  # token = var.github_tokens.prod
}

provider "github" {
  alias = "shared"
  # token = var.github_tokens.shared
}

provider "github" {
  alias = "infra"
  # token = var.github_tokens.infra
}

provider "github" {
  alias = "sandbox"
  # token = var.github_tokens.sandbox
}

# Vault provider configuration
provider "vault" {
  # address = var.vault_address
  # token   = var.vault_token
}

#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;#
#modules/control_repository/main.tf
# Ensure the runner group for mac-minis exists (relying on current org GitHub provider)
# resource "github_enterprise_runner_group" "mac_minis" { #enterprise scope runner group
resource "github_actions_runner_group" "mac_mini" { #org scope runner group
  provider   = github
  name       = "mac-minis"
  visibility = "selected"
}

# Fetch all allowed repositories for the org
data "github_repository" "repos" {
  for_each  = toset(var.macmini_allowed_repositories)
  full_name = "${var.org_name}/${each.value}"
}

# Attach the eligible repositories to the mac-minis runner group
resource "github_enterprise_runner_group_repository" "allow_repos" {
  for_each        = data.github_repository.repos
  provider        = github
  runner_group_id = github_enterprise_runner_group.mac_minis.id
  repository_id   = each.value.id
}

# Resolve allowed GitHub Apps by slug
data "github_app" "apps" {
  for_each = toset(var.allowed_github_apps)
  slug     = each.value
  provider = github
}

# Apply GitHub App allowlist as repository ruleset
resource "github_repository_ruleset" "app_allowlist" {
  for_each   = data.github_repository.repos
  provider   = github
  name       = "allow-github-apps-${each.key}"
  repository = each.value.full_name
  enforcement = "active"

  # rule {
  #   type       = "github_app"
  #   parameters = [for app in data.github_app.apps : app.id]
  # }
}

# Use Vault module to fetch GitHub credentials (per org)
module "vault_auth" {
  source         = "./modules/jwt-role"
  providers       = { vault = vault }
  vault_address  = var.vault_address
  vault_namespace = var.vault_namespace
}

#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;#

#modules/control_repository/variables.tf
variable "apm_code" {
  description = "4-letter code for the organization"
  type        = string
}

variable "org_name" {
  description = "GitHub organization name for context"
  type        = string
}

variable "macmini_allowed_repositories" {
  description = "Repositories allowed to use mac-mini runner group"
  type        = list(string)
  default     = []
}

variable "allowed_github_apps" {
  description = "List of allowed GitHub Apps slugs per org"
  type        = list(string)
  default     = []
}

variable "vault_address" {
  description = "Vault address"
  type        = string
}

variable "vault_namespace" {
  description = "Vault namespace"
  type        = string
}

#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;#
#modules/control_repository/versions.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.4"
    }
  }
}

#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;#
# modules/control_repository_per_app/main.tf
# Core resources managing a single app's GitHub runner permissions and App allowlist

# Ensure the runner group named 'mac-minis' exists (provided by org-level parent)
# data "github_enterprise_runner_group" "mac_minis" { #enterprise scope runner group
data "github_actions_runner_group" "mac_minis" {
  provider = github
  name     = "mac-minis"
}

# Fetch allowed repositories for this app
data "github_repository" "repos" {
  for_each  = toset(var.macmini_allowed_repositories)
  full_name = "${var.org_name}/${each.value}"
}

# Attach allowed repositories to runner group
# enterprise scope
# resource "github_enterprise_runner_group_repository" "allow_repos" {
#   for_each        = data.github_repository.repos
#   provider        = github
#   runner_group_id = runner_group_id = data.github_actions_runner_group.mac_minis.id # github_enterprise_runner_group.mac_minis.id
#   repository_id   = each.value.id
# }
# org scope
resource "github_actions_runner_group_repository" "allow_repos" {
  for_each        = data.github_repository.repos
  provider        = github
  runner_group_id = github_actions_runner_group.mac_mini.id
  repository_id   = each.value.repo_id
}

# Resolve allowed GitHub Apps by slug for this app
data "github_app" "apps" {
  for_each = toset(var.allowed_github_apps)
  slug     = each.value
  provider = github
}

# Apply repository GitHub App allowlist ruleset
resource "github_repository_ruleset" "app_allowlist" {
  for_each   = data.github_repository.repos
  provider   = github
  name       = "allow-github-apps-${each.key}"
  repository = each.value.full_name
  enforcement = "active"

  # rule {
  #   type       = "github_app"
  #   parameters = [for app in data.github_app.apps : app.id]
  # }
}

#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;#
# modules/control_repository_per_app/variables.tf
variable "org_name" {
  description = "GitHub organization name for repo context"
  type        = string
}

variable "apm_code" {
  description = "4-letter application code"
  type        = string
}

variable "macmini_allowed_repositories" {
  description = "List of repositories allowed to use the mac-minis runner group"
  type        = list(string)
  default     = []
}

variable "allowed_github_apps" {
  description = "GitHub App slugs allowed for this application"
  type        = list(string)
  default     = []
}
#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;#
# modules/control_repository_per_app/versions.tf

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}
#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;#
#modules/control_repository_per_app/provider.tf (optionaL)
provider "github" {
  alias = "default"
  # token and other settings can be passed down from root module providers
}
#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;#

#modules/jwt-role/main.tf
# ---------------------------------------------------------------------------------------------------------------------
# RESOURCE AND MODULE STATEMENTS
# ---------------------------------------------------------------------------------------------------------------------

locals {
  type       = local.plat == "ghec" ? "repo" : local.plat == "tfc" ? "tfws" : null
  kv_secretf = format("c1/kv/%s/data/%s/%s/%%s/%%s/%%s/+", local.plat, local.org, local.epm)
  tfc_bind = {
    terraform_organization_name = local.org
    terraform_project_name      = local.env
    terraform_workspace_name    = local.name
  }
  ghec_bind = {
    repository = format("%s/%s", local.org, local.name)
  }
  bind      = local.plat == "ghec" ? local.ghec_bind : local.plat == "tfc" ? local.tfc_bind : null
  audiences = local.plat == "ghec" ? ["vault.workload.identity", "https://github.com/${local.org}"] : local.plat == "tfc" ? ["vault.workload.identity", "https://app.terraform.io"] : null
}

resource "vault_policy" "this" {
  name = format("c1/%s/%s-%s", local.plat, local.type, local.name)
  policy = templatefile(
    "${path.module}/policies/read-multi-path.tpl.hvacl", {
      paths = [
        format(local.kv_secretf, local.env, local.name, local.ctx),
        format(local.kv_secretf, local.env, local.name, "all"),
        format(local.kv_secretf, local.env, "any", "all"),
        format(local.kv_secretf, "noenv", "any", "all"),
        format("c1/kv/platform/data/global/common/noenv/any/all/+"),
        format("c1/kv/platform/data/global/%s/noenv/any/all/+", local.epm),
      ]
    }
  )
}

resource "vault_jwt_auth_backend_role" "this" {
  backend         = local.path
  role_name       = local.name
  role_type       = "jwt"
  bound_audiences = local.audiences
  bound_claims    = local.bind
  user_claim      = "iss"
  token_policies = concat([
    vault_policy.this.name,
    ],
  local.pols)
  token_max_ttl = 3600
  token_ttl     = 600
}

#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;#
#modules/vault-jwt-role/variables.tf
# vim: filetype=terraform syntax=terraform softtabstop=2 tabstop=2 shiftwidth=2 fileencoding=utf-8 commentstring=#%s expandtab
# code: language=terraform insertSpaces=true tabSize=2

# ---------------------------------------------------------------------------------------------------------------------
# MODULE VARIABLE DECLARATIONS
# ---------------------------------------------------------------------------------------------------------------------

variable "object_name" {
  description = "Name of the workspace or repository"
  type        = string
}

variable "organization" {
  description = "Name of the organization housing the object"
  type        = string
}

variable "environment" {
  description = "Name of the project or environment housing the object"
  type        = string
}

variable "context" {
  description = "For Actions, name of the workflow; for workspaces, run phase (plan or apply)"
  type        = string
}

variable "epm_code" {
  type        = string
  description = "EPM Code of the object being onboarded"
  validation {
    error_message = "Should be exactly 4 characters long"
    condition     = length(var.epm_code) == 4
  }
}

variable "auth_mount_path" {
  description = "Path of the Auth Mount to create a role in"
  type        = string
  default     = "jwt"
}

locals {
  gh_strings = ["github", "ghec", "gh"]
  tf_strings = ["terraform", "tfc", "tf"]
}

variable "platform" {
  type        = string
  description = "Whether the object is TFC or GHEC related"
  validation {
    error_message = "platform must be one of 'github' or 'terraform'"
    condition     = contains(concat(local.gh_strings, local.tf_strings), var.platform)
  }
}

variable "additional_policies" {
  type        = list(string)
  description = "Any additional policies to add to the role"
  default     = []
}

locals {
  name = var.object_name
  org  = var.organization
  path = var.auth_mount_path
  env  = var.environment
  ctx  = var.context
  epm  = lower(var.epm_code)
  plat = contains(local.tf_strings, var.platform) ? "tfc" : contains(local.gh_strings, var.platform) ? "ghec" : null
  pols = var.additional_policies
}

#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;#
#modules/vault-jwt-role/versions.tf
terraform {
  required_version = "~> 1.4"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.4"
    }
  }
}
#
#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;#
#modules/vault-jwt-role/policies/read-multi-path.tpl.hvacl
# vim: filetype=hcl syntax=hcl softtabstop=2 tabstop=2 shiftwidth=2 fileencoding=utf-8 commentstring=#%s expandtab
# code: language=hcl insertSpaces=true tabSize=2
# Templated:%{ for path in paths ~}

path "${path}" {
  capabilities = ["read"]
}

# EndTemplate%{ endfor ~}


#modules/vault-jwt-role/outputs.tf
output "role_name" {
  value = vault_jwt_auth_backend_role.this.role_name
}

#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;#