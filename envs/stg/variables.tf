variable "env" {
  description = "Environment name (sandbox, dev, stg, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "az_count" {
  description = "Number of AZs to use"
  type        = number
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR for VPC"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "hbp-cc"
}

variable "terraform_runner_allow_assume_principal_arns" {
  description = "IAM user or role ARNs allowed to assume the Terraform runner role. Empty = policy only, no role."
  type        = list(string)
  default     = []
}
