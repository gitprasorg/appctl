# modules/github-control-logic/variables.tf

variable "organization_name" {
  type        = string
  description = "The GitHub Organization name (e.g., gitprasorg-prod)"
}

variable "apm_code" {
  type        = string
  description = "The 4-character Application Code (e.g., ABCD)"
}

# 1. Runner Whitelisting Variable
variable "mac_mini_runner_allowed_repos" {
  description = "Repository names allowed to use the Mac Mini runner group."
  type        = list(string)
  default     = []
}

# 2. GitHub App Access Variable
variable "github_apps" {
  description = "Map of GitHub App installations to repository name lists."
  type = map(object({
    installation_id = number
    repositories    = list(string)
  }))
  default = {}
}

# 3. VAULT POLICIES TO KEEP (Passed to the nested Vault module)
variable "additional_vault_policies" {
  type        = list(string)
  description = "Any additional Vault policies to add to the created JWT role."
  default     = []
}
