terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 6.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.3.0, < 5.0.0"
    }
  }
}

# The default provider will be used unless an alias is specified in a resource/module.
# We will define all four for explicit use.

provider "github" {
  alias = "gitprasorg-prod"
  # token = var.github_tokens.prod
}

provider "github" {
  alias = "gitprasorg-shared"
  # token = var.github_tokens.shared
}

provider "github" {
  alias = "gitprasorg-infra"
  # token = var.github_tokens.infra
}

provider "github" {
  alias = "gitprasorg-sandbox"
  # token = var.github_tokens.sandbox
}

# Vault provider configuration
provider "vault" {
  # address = var.vault_address
  # token   = var.vault_token
}
