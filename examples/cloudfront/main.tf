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

  bucket_name       = "example.com"
  enable_cloudfront = true
  price_class       = "PriceClass_100"

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "bucket_id" {
  description = "S3 bucket name."
  value       = module.s3_static_website.bucket_id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID."
  value       = module.s3_static_website.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name."
  value       = module.s3_static_website.cloudfront_distribution_domain_name
}
