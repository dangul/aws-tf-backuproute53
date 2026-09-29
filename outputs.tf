output "backup_function_arn" {
  description = "ARN of the backup Lambda function"
  value       = aws_lambda_function.backup_function.arn
}

output "failed_backup_alarm_topic_arn" {
  description = "SNS topic ARN for Route 53 backup failure notifications"
  value       = aws_sns_topic.failed_backup_alarm_topic.arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket created for backups"
  value       = var.create_s3_bucket ? aws_s3_bucket.backup_bucket[0].id : var.s3_bucket_name
}