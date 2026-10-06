output "bucket_id" {
  description = "The name (ID) of the S3 bucket used for static website hosting."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket, in the format arn:aws:s3:::<bucket-name>."
  value       = aws_s3_bucket.this.arn
}

output "bucket_website_endpoint" {
  description = "The S3 static website endpoint URL, in the format <bucket-name>.s3-website-<region>.amazonaws.com."
  value       = aws_s3_bucket_website_configuration.this.website_endpoint
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution. Null when enable_cloudfront is false."
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.this[0].id : null
}

output "cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution (e.g. <id>.cloudfront.net). Null when enable_cloudfront is false."
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.this[0].domain_name : null
}

output "route53_zone_id" {
  description = "The ID of the Route 53 hosted zone created by this module. Null when create_route53_zone is false."
  value       = var.create_route53_zone ? aws_route53_zone.this[0].zone_id : null
}

output "acm_certificate_arn" {
  description = "The ARN of the ACM certificate provisioned for the CloudFront distribution. Null when create_acm_certificate is false."
  value       = local.create_acm ? aws_acm_certificate.this[0].arn : null
}
