terraform {
  backend "s3" {
    bucket         = "bucket-state-terraform-CHANGEME"
    key            = "route53-backup/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}