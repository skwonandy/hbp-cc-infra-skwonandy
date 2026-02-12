output "terraform_caller_arn" {
  description = "Terraform 実行時の IAM identity"
  value       = data.aws_caller_identity.current.arn
}

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

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_instance_endpoint
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.elasticache.redis_endpoint
}

output "s3_app_bucket" {
  description = "App S3 bucket name"
  value       = module.s3.app_bucket_id
}

output "s3_frontend_bucket" {
  description = "Frontend S3 bucket name (CloudFront origin)"
  value       = module.s3.frontend_bucket_id
}

# dev では Batch を使用しないため output なし

output "ecr_api_url" {
  description = "ECR repository URL for API (push image here)"
  value       = module.cicd.ecr_api_url
}

output "ecr_worker_url" {
  description = "ECR repository URL for worker (null in dev; worker is not deployed)"
  value       = module.cicd.ecr_worker_url
}

output "github_actions_deploy_role_arn" {
  description = "Register this as AWS_DEPLOY_ROLE_ARN in GitHub Environment 'dev' secrets"
  value       = module.cicd.github_actions_deploy_role_arn
}

output "api_url" {
  description = "API endpoint (ALB)"
  value       = "http://${module.alb.alb_dns_name}"
}

output "frontend_url" {
  description = "Frontend URL (CloudFront)"
  value       = module.cloudfront.cloudfront_url
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation)"
  value       = module.cloudfront.cloudfront_distribution_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name (for deploy workflow)"
  value       = module.ecs.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS service name (for deploy workflow)"
  value       = module.ecs.ecs_service_name
}

output "terraform_runner_policy_arn" {
  description = "ARN of the Terraform runner policy (scoped to this env)"
  value       = module.terraform_runner_policy.policy_arn
}

output "terraform_runner_role_arn" {
  description = "ARN of the Terraform runner role. Assume this role before running terraform plan/apply in this env."
  value       = module.terraform_runner_policy.role_arn
}
