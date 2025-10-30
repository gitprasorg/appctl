resource "github_app_installation_repository" "app_installation" {
  for_each = toset(var.repositories)

  installation_id = var.installation_id
  repository      = each.value
}
