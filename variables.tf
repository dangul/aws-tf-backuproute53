variable "aws_region" {
  type        = string
  description = "AWS region to deploy to"
  default     = "eu-north-1"
}

variable "stack_name" {
  type        = string
  description = "Name prefix (corresponds to AWS::StackName in CFN)"
  default     = "route53-backup"
}

variable "s3_bucket_name" {
  type        = string
  description = "Name of the S3 bucket where backups are stored. NOTE: Recommended to reside in a different account than Route 53, but currently runs in the same account by decision."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.s3_bucket_name))
    error_message = "Bucket name does not match the required pattern."
  }
}

variable "create_s3_bucket" {
  type        = bool
  description = "Whether Terraform should create the S3 bucket (set to false if it already exists)"
  default     = true
}

variable "s3_bucket_force_destroy" {
  type        = bool
  description = "Allow bucket deletion even if it contains objects (use caution in production!)"
  default     = false
}

variable "schedule_expression" {
  type        = string
  description = "Cron expression for when the EventBridge rule should trigger the Lambda function"
  default     = "cron(0 2 * * ? *)"
}

variable "expire_log" {
  type        = number
  description = "Expire CloudWatch log after (days)"
  default     = 14

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.expire_log)
    error_message = "expire_log must be one of the allowed CloudWatch retention values."
  }
}

variable "test_notification" {
  type        = string
  description = "Set to a non-empty value (for example, TEST) to send a test email on each Lambda invocation"
  default     = ""
}

variable "notification_email" {
  type        = string
  description = "Email address that receives Route 53 backup notifications"
  default     = "notifications@example.com"
}