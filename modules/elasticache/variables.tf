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
  description = "Private subnet IDs for ElastiCache"
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "Security group IDs allowed to connect (e.g. ECS)"
}

variable "node_type" {
  type        = string
  default     = "cache.t4g.micro"
  description = "ElastiCache node type"
}

variable "num_cache_nodes" {
  type        = number
  default     = 1
  description = "Number of cache nodes"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags"
}
