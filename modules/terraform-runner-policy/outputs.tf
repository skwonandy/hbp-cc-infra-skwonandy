output "policy_arn" {
  description = "ARN of the Terraform runner core policy (backward compat; runner has core + app attached)"
  value       = aws_iam_policy.runner_core.arn
}

output "policy_app_arn" {
  description = "ARN of the Terraform runner app policy"
  value       = aws_iam_policy.runner_app.arn
}

output "role_arn" {
  description = "ARN of the Terraform runner role (empty if allow_assume_principal_arns was not set)"
  value       = length(aws_iam_role.runner) > 0 ? aws_iam_role.runner[0].arn : null
}

output "role_name" {
  description = "Name of the Terraform runner role (empty if role was not created)"
  value       = length(aws_iam_role.runner) > 0 ? aws_iam_role.runner[0].name : null
}
