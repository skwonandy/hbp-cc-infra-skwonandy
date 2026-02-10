output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "azs" {
  description = "Availability zones in use"
  value       = local.azs
}

output "internal_security_group_id" {
  description = "Security group ID for internal VPC traffic"
  value       = aws_security_group.vpc_internal.id
}
