output "job_queue_name" {
  description = "Job queue name (for aws_caller: env_default)"
  value       = aws_batch_job_queue.default.name
}

output "job_definition_name" {
  description = "Job definition name (for aws_caller: env_fastapi_default_job)"
  value       = aws_batch_job_definition.fastapi_default.name
}
