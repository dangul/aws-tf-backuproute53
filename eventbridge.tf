resource "aws_cloudwatch_event_rule" "backup_function_trigger" {
  name                = "${var.stack_name}-backup-trigger"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "backup_function_target" {
  rule      = aws_cloudwatch_event_rule.backup_function_trigger.name
  target_id = "BackupFunctionTrigger"
  arn       = aws_lambda_function.backup_function.arn

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 2
  }
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backup_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.backup_function_trigger.arn
}