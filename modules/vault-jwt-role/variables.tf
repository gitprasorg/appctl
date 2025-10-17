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
