resource "aws_sns_topic" "failed_backup_alarm_topic" {
  name         = "${var.stack_name}-failed-backups"
  display_name = "Route 53 backup failures"
}

resource "aws_sns_topic_subscription" "failed_backup_email_subscription" {
  topic_arn = aws_sns_topic.failed_backup_alarm_topic.arn
  protocol  = "email"
  endpoint  = var.notification_email
}