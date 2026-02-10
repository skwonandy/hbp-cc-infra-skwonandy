variable "env" {
  type = string
}

variable "project_name" {
  type    = string
  default = "hbp-cc"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "batch_job_image" {
  type        = string
  default     = "public.ecr.aws/amazonlinux/amazonlinux:latest"
  description = "Container image for Batch job (override with ECR image)"
}
