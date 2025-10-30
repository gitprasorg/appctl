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
}

locals {
  app_installations = flatten([
    for org_key, org_value in local.org_configs : [
      for app_key, app_value in org_value.apps : [
        for app_slug, install_id in lookup(app_value, "github_app_installations", {}) : {
          org             = org_key
          app_name        = app_key
          app_slug        = app_slug
          installation_id = install_id
          repositories    = app_value.macmini_allowed_repositories
        }
      ]
    ]
  ])
}

module "github_app_installation" {
  for_each = { for install in local.app_installations : "${install.org}-${install.app_name}-${install.app_slug}" => install }

  source = "./modules/github-app"

  providers = {
    github = github
  }

  installation_id = each.value.installation_id
  repositories    = each.value.repositories
}
