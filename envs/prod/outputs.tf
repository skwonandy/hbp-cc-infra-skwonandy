output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "terraform_runner_policy_arn" {
  description = "ARN of the Terraform runner policy (scoped to this env)"
  value       = module.terraform_runner_policy.policy_arn
}

output "terraform_runner_role_arn" {
  description = "ARN of the Terraform runner role. Assume this role before running terraform plan/apply in this env."
  value       = module.terraform_runner_policy.role_arn
}
