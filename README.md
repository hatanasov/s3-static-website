# s3-static-website

A reusable Terraform module that provisions S3 static website hosting with optional CloudFront CDN, ACM SSL/TLS certificates, and Route 53 DNS management.

## Features

- S3 bucket configured for static website hosting with customisable index and error documents
- Object versioning support (enabled or suspended)
- Public-read bucket policy for direct S3 hosting, or private bucket with CloudFront OAC (SigV4) when CDN is enabled
- CloudFront distribution with Origin Access Control, HTTPS redirect, and configurable price class
- ACM certificate provisioned in `us-east-1` with DNS validation (required for CloudFront)
- Route 53 hosted zone creation or reuse of an existing zone
- Automatic DNS A-alias record pointing to CloudFront or the S3 website endpoint
- Input validation and `lifecycle` preconditions to catch configuration mistakes before `apply`
- Consistent resource tagging via a single `tags` variable

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.3.0 |
| AWS Provider | >= 5.0 |

## Important: Provider Configuration

This module uses `configuration_aliases` to require a second AWS provider aliased to `us-east-1`. ACM certificates for CloudFront **must** be created in `us-east-1` regardless of the default region, and this alias is how the module enforces that.

Every caller must declare both providers and pass them explicitly via the `providers` argument:

```hcl
provider "aws" {
  region = "eu-west-1"   # your default region
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

module "s3_static_website" {
  source = "path/to/module"

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }

  # ...
}
```

Omitting the `providers` block will cause Terraform to error because the `aws.us-east-1` alias has no default.

## Usage

### Minimal — S3 only

The simplest configuration: a public S3 static website with no CDN.

```hcl
provider "aws" {
  region = "eu-west-1"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

module "s3_static_website" {
  source = "path/to/module"

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }

  bucket_name = "my-static-website"

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

output "website_url" {
  value = module.s3_static_website.bucket_website_endpoint
}
```

### CloudFront — private bucket with OAC

Enables a CloudFront distribution in front of the S3 bucket. The bucket becomes private; CloudFront accesses it via Origin Access Control.

```hcl
provider "aws" {
  region = "eu-west-1"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

module "s3_static_website" {
  source = "path/to/module"

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }

  bucket_name       = "my-cloudfront-website"
  enable_cloudfront = true
  price_class       = "PriceClass_100"

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

output "cloudfront_domain" {
  value = module.s3_static_website.cloudfront_distribution_domain_name
}
```

### Full stack — CloudFront + ACM + Route 53

Creates a CloudFront distribution with a custom domain, an ACM certificate with DNS validation, and a Route 53 hosted zone with an A-alias record.

```hcl
provider "aws" {
  region = "eu-west-1"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

module "s3_static_website" {
  source = "path/to/module"

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }

  bucket_name            = "my-full-stack-website"
  enable_cloudfront      = true
  price_class            = "PriceClass_100"
  create_acm_certificate = true
  domain_name            = "example.com"
  cloudfront_aliases     = ["example.com", "www.example.com"]
  create_route53_zone    = true

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

output "cloudfront_domain" {
  value = module.s3_static_website.cloudfront_distribution_domain_name
}

output "route53_zone_id" {
  value = module.s3_static_website.route53_zone_id
}

output "acm_certificate_arn" {
  value = module.s3_static_website.acm_certificate_arn
}
```

## Inputs

| Name | Type | Description | Default | Required |
|------|------|-------------|---------|:--------:|
| `bucket_name` | `string` | The name of the S3 bucket. Must be 3–63 characters, lowercase alphanumeric and hyphens only, no leading/trailing hyphens, and not an IPv4 address. | — | yes |
| `index_document` | `string` | The filename served when a request targets a directory. | `"index.html"` | no |
| `error_document` | `string` | The filename served when a requested object is not found. Set to `""` to omit. | `"error.html"` | no |
| `force_destroy` | `bool` | When `true`, allows the bucket to be deleted even if it contains objects. | `false` | no |
| `enable_versioning` | `bool` | When `true`, enables S3 object versioning. When `false`, versioning is suspended. | `false` | no |
| `enable_cloudfront` | `bool` | When `true`, creates a CloudFront distribution with OAC and sets the bucket to private. | `false` | no |
| `price_class` | `string` | CloudFront price class controlling which edge locations serve content. Accepted values: `PriceClass_100`, `PriceClass_200`, `PriceClass_All`. | `"PriceClass_100"` | no |
| `cloudfront_aliases` | `list(string)` | Alternate domain names (CNAMEs) for the CloudFront distribution. Requires `enable_cloudfront = true` and `create_acm_certificate = true`. | `[]` | no |
| `create_acm_certificate` | `bool` | When `true`, provisions an ACM certificate in `us-east-1` and attaches it to CloudFront. Requires `enable_cloudfront = true` and a non-empty `domain_name`. | `false` | no |
| `domain_name` | `string` | The custom domain name for the website. Required when `create_acm_certificate = true` or `cloudfront_aliases` is non-empty. | `""` | no |
| `create_route53_zone` | `bool` | When `true`, creates a new Route 53 hosted zone for `domain_name`. | `false` | no |
| `route53_zone_id` | `string` | ID of an existing Route 53 hosted zone. Used when `create_route53_zone = false`. | `""` | no |
| `tags` | `map(string)` | Key-value tags applied to all AWS resources created by this module. | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `bucket_id` | The name (ID) of the S3 bucket. |
| `bucket_arn` | The ARN of the S3 bucket. |
| `bucket_website_endpoint` | The S3 static website endpoint URL (`<bucket>.s3-website-<region>.amazonaws.com`). |
| `cloudfront_distribution_id` | The ID of the CloudFront distribution. `null` when `enable_cloudfront = false`. |
| `cloudfront_distribution_domain_name` | The domain name of the CloudFront distribution (e.g. `<id>.cloudfront.net`). `null` when `enable_cloudfront = false`. |
| `route53_zone_id` | The ID of the Route 53 hosted zone created by this module. `null` when `create_route53_zone = false`. |
| `acm_certificate_arn` | The ARN of the ACM certificate. `null` when `create_acm_certificate = false`. |

## Notes

- **CloudFront uses OAC, not OAI.** The distribution authenticates to S3 using Origin Access Control with SigV4 signing. The older Origin Access Identity (OAI) mechanism is not used.
- **ACM certificates are always created in `us-east-1`.** CloudFront requires certificates from that region regardless of the AWS region you deploy the rest of your infrastructure to. The `aws.us-east-1` provider alias handles this transparently.
- **`price_class = "PriceClass_100"` is the cheapest option.** It serves traffic only from edge locations in North America and Europe. Use `PriceClass_200` to add Asia, Middle East, and Africa, or `PriceClass_All` for global coverage.
