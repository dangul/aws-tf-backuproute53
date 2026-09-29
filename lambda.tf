data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

data "archive_file" "backup_function_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/lambda/index.zip"
}

resource "aws_iam_role" "backup_function_role" {
  name = "${var.stack_name}-backup-function-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "backup_route53_policy" {
  name = "BackupRoute53Policy"
  role = aws_iam_role.backup_function_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.stack_name}-backupdns:*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:s3:::${var.s3_bucket_name}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.failed_backup_alarm_topic.arn
      }
    ]
  })
}

resource "aws_lambda_function" "backup_function" {
  function_name = "${var.stack_name}-backupdns"
  handler       = "index.lambda_handler"
  role          = aws_iam_role.backup_function_role.arn
  runtime       = "python3.13"
  timeout       = 300

  filename         = data.archive_file.backup_function_zip.output_path
  source_code_hash = data.archive_file.backup_function_zip.output_base64sha256

  logging_config {
    log_format = "JSON"
  }

  environment {
    variables = {
      S3_BUCKET_NAME = var.s3_bucket_name
      SNS_TOPIC_ARN  = aws_sns_topic.failed_backup_alarm_topic.arn
      TEST           = var.test_notification
    }
  }

  depends_on = [
    aws_iam_role_policy.backup_route53_policy,
    aws_cloudwatch_log_group.backup_function_log_group,
  ]
}