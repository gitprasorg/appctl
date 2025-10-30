variable "installation_id" {
  description = "The installation ID of the GitHub App."
  type        = string
}

variable "repositories" {
  description = "A list of repositories to install the GitHub App on."
  type        = list(string)
  default     = []
}
