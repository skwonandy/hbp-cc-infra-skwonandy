output "redis_endpoint" {
  description = "Redis primary endpoint (address:port)"
  value       = "${aws_elasticache_cluster.main.cache_nodes[0].address}:${aws_elasticache_cluster.main.cache_nodes[0].port}"
}

output "redis_host" {
  description = "Redis host only (for REDIS_HOST env)"
  value       = aws_elasticache_cluster.main.cache_nodes[0].address
}

output "redis_security_group_id" {
  description = "ElastiCache security group ID"
  value       = aws_security_group.redis.id
}
