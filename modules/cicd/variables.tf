variable "env" {
  type = string
}

variable "project_name" {
  type    = string
  default = "hbp-cc"
}

variable "github_org_repo" {
  type        = string
  default     = ""
  description = "GitHub org/repo for OIDC (e.g. myorg/hbp-cc). Empty to skip OIDC role."
}

variable "create_oidc_provider" {
  type        = bool
  default     = false
  description = "Create GitHub OIDC provider in this account. Set true in exactly one env (e.g. min); others use data source."
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "create_worker_repository" {
  type        = bool
  default     = true
  description = "Create ECR repository for arq worker. Set to false for min env where worker is not deployed."
}
