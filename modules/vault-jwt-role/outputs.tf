# vim: filetype=terraform syntax=terraform softtabstop=2 tabstop=2 shiftwidth=2 fileencoding=utf-8 commentstring=#%s expandtab
# code: language=terraform insertSpaces=true tabSize=2

# ---------------------------------------------------------------------------------------------------------------------
# SET MODULE OUTPUTS FOR DOWNSTREAM CONSUMPTION
# ---------------------------------------------------------------------------------------------------------------------

output "role_name" {
  value = vault_jwt_auth_backend_role.this.role_name
}
