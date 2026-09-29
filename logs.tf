resource "aws_cloudwatch_log_group" "backup_function_log_group" {
  name              = "/aws/lambda/${var.stack_name}-backupdns"
  retention_in_days = var.expire_log
}

resource "aws_cloudwatch_log_metric_filter" "failed_backup_metric_filter" {
  name           = "FailedBackupsFilter"
  log_group_name = aws_cloudwatch_log_group.backup_function_log_group.name
  pattern        = "?failed"

  metric_transformation {
    name          = "FailedBackups"
    namespace     = "Route53Backup"
    value         = "1"
    default_value = "0"
  }
}