# vim: filetype=terraform syntax=terraform softtabstop=2 tabstop=2 shiftwidth=2 fileencoding=utf-8 commentstring=#%s expandtab
# code: language=terraform insertSpaces=true tabSize=2

# ---------------------------------------------------------------------------------------------------------------------
# SET TERRAFORM AND PROVIDER REQUIREMENTS FOR RUNNING THIS MODULE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = "~> 1.4"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.4"
    }
  }
}
