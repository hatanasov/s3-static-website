terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

module "s3_static_website" {
  source = "../../"

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }

  bucket_name = "example.com"

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "bucket_id" {
  description = "S3 bucket name."
  value       = module.s3_static_website.bucket_id
}

output "bucket_website_endpoint" {
  description = "S3 website endpoint URL."
  value       = module.s3_static_website.bucket_website_endpoint
}
