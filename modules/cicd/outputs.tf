output "ecr_api_url" {
  description = "ECR repository URL for API image"
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_worker_url" {
  description = "ECR repository URL for worker image (null when create_worker_repository = false)"
  value       = length(aws_ecr_repository.worker) > 0 ? aws_ecr_repository.worker[0].repository_url : null
}

output "ecr_frontend_url" {
  description = "ECR repository URL for frontend image"
  value       = aws_ecr_repository.frontend.repository_url
}

output "github_actions_deploy_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC deploy. Register as AWS_DEPLOY_ROLE_ARN in GitHub Environment secrets."
  value       = var.github_org_repo != "" ? aws_iam_role.github_actions_deploy[0].arn : null
}
