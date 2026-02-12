output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name (e.g. xxxxx.cloudfront.net)"
  value       = aws_cloudfront_distribution.api.domain_name
}

output "cloudfront_url" {
  description = "API base URL (https) without path"
  value       = "https://${aws_cloudfront_distribution.api.domain_name}"
}

output "distribution_id" {
  description = "CloudFront distribution ID (for invalidation if needed)"
  value       = aws_cloudfront_distribution.api.id
}
