resource "aws_cloudwatch_metric_alarm" "failed_backup_alarm" {
  alarm_name          = "${var.stack_name}-failed-backups"
  alarm_description   = "One or more Route 53 zone backups failed."
  namespace           = "Route53Backup"
  metric_name         = "FailedBackups"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.failed_backup_alarm_topic.arn]
}