variable "env" {
  description = "Environment name (sandbox, dev, stg, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "az_count" {
  description = "Number of availability zones to use (1 or 2)"
  type        = number
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "hbp-cc"
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
