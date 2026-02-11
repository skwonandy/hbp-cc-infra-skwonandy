variable "env" {
  type        = string
  description = "Environment name"
}

variable "project_name" {
  type        = string
  default     = "hbp-cc"
  description = "Project name for naming"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for RDS"
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "Security group IDs allowed to connect to RDS (e.g. ECS)"
}

variable "instance_class" {
  type        = string
  default     = "db.t4g.micro"
  description = "RDS instance class"
}

variable "allocated_storage_gb" {
  type        = number
  default     = 20
  description = "Allocated storage in GB"
}

variable "multi_az" {
  type        = bool
  default     = false
  description = "Enable Multi-AZ"
}

variable "deletion_protection" {
  type        = bool
  default     = false
  description = "Enable deletion protection (recommended true for prod)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags"
}

variable "db_password" {
  type        = string
  description = "Master password for RDS (use Secrets Manager in production; do not commit real value)"
  sensitive   = true
}
