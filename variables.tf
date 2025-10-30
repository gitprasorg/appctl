variable "org_apps" {
  description = "Map of application configurations within the org"
  type = map(object({
    apm_code                    = string
    macmini_allowed_repositories = list(string)
    allowed_github_apps         = list(string)
  }))
}

variable "vault_address" {
  description = "Vault address"
  type        = string
}

variable "vault_namespace" {
  description = "Vault namespace"
  type        = string
}

variable "org_name" {
  description = "GitHub organization name for repo context"
  type        = string
}
