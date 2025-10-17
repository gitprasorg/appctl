# vim: filetype=terraform syntax=terraform softtabstop=2 tabstop=2 shiftwidth=2 fileencoding=utf-8 commentstring=#%s expandtab
# code: language=terraform insertSpaces=true tabSize=2

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
