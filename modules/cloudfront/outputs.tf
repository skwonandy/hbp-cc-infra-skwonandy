output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for invalidation)"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name (e.g. d1234abcd.cloudfront.net)"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.frontend.arn
}

output "cloudfront_url" {
  description = "Frontend URL (https)"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}
