# AWS Route 53 Backup

This Terraform project deploys an automated backup solution for AWS Route 53 hosted zones.

The solution creates a scheduled AWS Lambda function that lists all Route 53 hosted zones in the AWS account, exports their DNS records in a BIND-style zone file format, and stores the backups in an S3 bucket. It also configures CloudWatch logging, failure metrics, a CloudWatch alarm, and SNS email notifications for backup failures.

## What gets deployed

The Terraform configuration provisions the following AWS resources:

- An S3 bucket for Route 53 zone backups, unless an existing bucket is used.
- S3 bucket versioning, server-side encryption, public access blocking, and lifecycle rules.
- A Python AWS Lambda function that performs the Route 53 backup.
- An IAM role and IAM policy for the Lambda function.
- An EventBridge scheduled rule that invokes the Lambda function.
- A CloudWatch log group for Lambda logs.
- A CloudWatch log metric filter for failed backups.
- A CloudWatch metric alarm for backup failures.
- An SNS topic and email subscription for notifications.

## How it works

1. EventBridge invokes the Lambda function according to `schedule_expression`.
2. The Lambda function lists all Route 53 hosted zones in the account.
3. For each hosted zone, the function retrieves all resource record sets.
4. The records are converted into a BIND-style text format.
5. Each zone is uploaded to S3 under a UTC timestamped folder.

Example S3 object path:

```text
2026-09-29T02:00Z/example.com.zone
```

If a zone backup fails, the Lambda function logs the failure. The CloudWatch log metric filter can then publish the custom `Route53Backup/FailedBackups` metric, which is monitored by a CloudWatch alarm connected to the SNS topic.

## Repository structure

```text
.
├── backend.tf              # Terraform remote state backend configuration
├── cloudwatch_alarm.tf     # CloudWatch alarm for backup failures
├── eventbridge.tf          # Scheduled EventBridge trigger for Lambda
├── lambda.tf               # Lambda function, package, IAM role, and permissions
├── lambda/
│   ├── index.py            # Python Lambda source code
│   └── index.zip           # Generated Lambda package archive
├── logs.tf                 # CloudWatch log group and metric filter
├── outputs.tf              # Terraform outputs
├── providers.tf            # Terraform and provider requirements
├── s3.tf                   # S3 backup bucket configuration
├── sns.tf                  # SNS topic and email subscription
├── terraform.tfvars        # Local variable values
└── variables.tf            # Input variable definitions
```

## Requirements

- Terraform `>= 1.5`
- AWS provider `~> 5.0`
- Archive provider `~> 2.4`
- AWS credentials configured for the target account
- Permissions to manage:
  - Lambda
  - IAM roles and policies
  - Route 53 read access
  - S3
  - EventBridge
  - CloudWatch Logs and Alarms
  - SNS
- An S3 bucket and DynamoDB table for Terraform remote state, if using the included backend configuration

## Backend configuration

The project uses an S3 backend defined in `backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "bucket-state-terraform-CHANGEME"
    key            = "route53-backup/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

Before running `terraform init`, update the backend values to match your environment. The backend S3 bucket and DynamoDB lock table must already exist.

If you do not want to use a remote backend, remove or modify `backend.tf` before initializing Terraform.

## Configuration

Configure the deployment by copying `terraform.tfvars.example` to `terraform.tfvars` and editing the values, or by passing variables on the command line.

Example:

```hcl
s3_bucket_name     = "my-route53-backups-bucket"
notification_email = "admin@example.com"
stack_name         = "route53-backup"
aws_region         = "eu-north-1"
```

> Note: S3 bucket names must be globally unique across AWS.

## Input variables

| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `aws_region` | `string` | `eu-north-1` | AWS region where regional resources are deployed. Route 53 itself is a global service. |
| `stack_name` | `string` | `route53-backup` | Name prefix used for AWS resources. |
| `s3_bucket_name` | `string` | n/a | Name of the S3 bucket where backups are stored. |
| `create_s3_bucket` | `bool` | `true` | Whether Terraform should create the S3 bucket. Set to `false` to use an existing bucket. |
| `s3_bucket_force_destroy` | `bool` | `false` | Allows deletion of the S3 bucket even if it contains objects. Use with caution. |
| `schedule_expression` | `string` | `cron(0 2 * * ? *)` | EventBridge schedule expression for the backup Lambda. Default is daily at 02:00 UTC. |
| `expire_log` | `number` | `14` | CloudWatch log retention period in days. Must be one of the allowed AWS retention values. |
| `test_notification` | `string` | empty string | Set to a non-empty value, for example `TEST`, to send a test email on each Lambda invocation. |
| `notification_email` | `string` | `notifications@example.com` | Email address that receives Route 53 backup notifications. |

## Outputs

| Output | Description |
| --- | --- |
| `backup_function_arn` | ARN of the Route 53 backup Lambda function. |
| `failed_backup_alarm_topic_arn` | ARN of the SNS topic used for failure notifications. |
| `s3_bucket_name` | Name of the S3 bucket used for backups. |

## Usage

### 1. Configure AWS credentials

Make sure your shell is authenticated to the correct AWS account.

For example:

```bash
aws sts get-caller-identity
```

### 2. Configure Terraform variables

Create and edit `terraform.tfvars`:

```bash
cp terraform.tfvars.example terraform.tfvars
```

```hcl
s3_bucket_name     = "my-route53-backups-bucket"
notification_email = "admin@example.com"
stack_name         = "route53-backup"
aws_region         = "eu-north-1"
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review the plan

```bash
terraform plan
```

### 5. Apply the configuration

```bash
terraform apply
```

### 6. Confirm the SNS email subscription

After deployment, AWS SNS sends a confirmation email to `notification_email`.

Open the email and confirm the subscription. Email notifications will not be delivered until the subscription is confirmed.

## Running a manual backup

You can invoke the Lambda function manually from the AWS CLI:

```bash
aws lambda invoke \
  --function-name route53-backup-backupdns \
  --payload '{}' \
  response.json
```

If you changed `stack_name`, replace `route53-backup-backupdns` with:

```text
<stack_name>-backupdns
```

## Testing notifications

To send a test email every time the Lambda runs, set `test_notification` to a non-empty value:

```hcl
test_notification = "TEST"
```

Then apply the change:

```bash
terraform apply
```

Set it back to an empty string when testing is complete:

```hcl
test_notification = ""
```

## Backup format

The Lambda function stores one `.zone` file per hosted zone. Records are written in a simple BIND-style format, for example:

```text
example.com. 300 IN A 203.0.113.10
www.example.com. 300 IN CNAME example.com
```

Route 53 alias records are represented with a comment and an approximate record line:

```text
; ALIAS example.com -> dualstack.example-load-balancer.amazonaws.com (A)
example.com. 60 IN A dualstack.example-load-balancer.amazonaws.com ; alias
```

## S3 lifecycle and retention

When Terraform creates the S3 bucket, the following settings are applied:

- Bucket versioning is enabled.
- Server-side encryption uses `AES256`.
- Public access is blocked.
- Current backup objects expire after 365 days.
- Non-current object versions expire after 90 days.

If `create_s3_bucket = false`, Terraform does not manage these S3 bucket settings. In that case, make sure the existing bucket has the security and lifecycle configuration you require.

## Destroying the resources

To remove the deployed resources:

```bash
terraform destroy
```

By default, `s3_bucket_force_destroy` is `false`. If the S3 bucket contains backup objects, Terraform may fail to delete the bucket. To allow Terraform to delete a non-empty bucket, set:

```hcl
s3_bucket_force_destroy = true
```

Use this option carefully, especially in production environments.

## Security notes

- The Lambda function has read-only access to Route 53 hosted zones and record sets.
- The Lambda function can write objects to the configured S3 bucket.
- The Lambda function can publish messages to the SNS topic created by this project.
- The managed S3 bucket blocks public access and enables server-side encryption.
- Consider storing backups in a separate AWS account for stronger isolation.

## Troubleshooting

### No email notifications are received

- Confirm the SNS email subscription.
- Check that `notification_email` is correct.
- Review the SNS topic subscription status in the AWS Console.

### Backups are not appearing in S3

- Check the Lambda logs in CloudWatch under `/aws/lambda/<stack_name>-backupdns`.
- Verify that the Lambda IAM policy allows `s3:PutObject` for the configured bucket.
- Confirm that the configured bucket exists if `create_s3_bucket = false`.

### Terraform cannot initialize the backend

- Verify that the backend S3 bucket exists.
- Verify that the DynamoDB lock table exists.
- Confirm that the backend region is correct.
- Confirm that your AWS credentials have access to the backend resources.