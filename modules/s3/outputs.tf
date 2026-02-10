output "app_bucket_id" {
  description = "App S3 bucket ID"
  value       = aws_s3_bucket.app.id
}

output "app_bucket_arn" {
  description = "App S3 bucket ARN"
  value       = aws_s3_bucket.app.arn
}

output "frontend_bucket_id" {
  description = "Frontend S3 bucket ID (CloudFront origin)"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_bucket_arn" {
  description = "Frontend S3 bucket ARN"
  value       = aws_s3_bucket.frontend.arn
}

output "frontend_bucket_regional_domain_name" {
  description = "Frontend S3 bucket regional domain name (CloudFront origin)"
  value       = aws_s3_bucket.frontend.bucket_regional_domain_name
}
