# ── LOCALS ─────────────────────────────────────────────────────────────
# Requirements: 4.3, 5.2, 5.3

locals {
  # True when both CloudFront and ACM certificate creation are requested.
  create_acm = var.enable_cloudfront && var.create_acm_certificate

  # True when a Route 53 zone is available — either newly created by this
  # module or supplied as an existing zone ID by the caller.
  zone_available = var.create_route53_zone || var.route53_zone_id != ""

  # Resolves to the zone ID that DNS records should target. Prefers the
  # newly created zone when create_route53_zone = true; falls back to the
  # caller-supplied zone ID otherwise.
  effective_zone_id = var.create_route53_zone ? aws_route53_zone.this[0].zone_id : var.route53_zone_id

  # True only when both ACM certificate creation and a zone are available,
  # which is required before ACM DNS validation records can be written.
  create_acm_validation = local.create_acm && local.zone_available
}

# ── S3 BUCKET ──────────────────────────────────────────────────────────
# Requirements: 1.1, 1.4, 1.5, 1.6, 6.14, 6.15

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags

  lifecycle {
    # Requirement 6.14: cloudfront_aliases must be empty when CloudFront is disabled.
    precondition {
      condition     = length(var.cloudfront_aliases) == 0 || var.enable_cloudfront
      error_message = "cloudfront_aliases requires enable_cloudfront = true."
    }

    # Requirement 4.7 / 6.10: domain_name must be set when ACM certificate creation is requested.
    precondition {
      condition     = !var.create_acm_certificate || var.domain_name != ""
      error_message = "domain_name must be non-empty when create_acm_certificate = true."
    }

    # Requirement 6.15: A Route 53 zone must be available whenever DNS records are needed
    # (i.e. when a zone is implicitly required for ACM validation or website DNS).
    # DNS records are needed when either create_route53_zone or a non-empty route53_zone_id is
    # expected but neither is provided while ACM validation is required.
    precondition {
      condition     = !local.create_acm || local.zone_available
      error_message = "A Route 53 zone is required for DNS records. Set create_route53_zone = true or provide route53_zone_id."
    }
  }
}

# ── S3 WEBSITE CONFIGURATION ───────────────────────────────────────────
# Requirements: 1.2, 1.3

resource "aws_s3_bucket_website_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  index_document {
    suffix = var.index_document
  }

  dynamic "error_document" {
    for_each = var.error_document != "" ? [var.error_document] : []
    content {
      key = error_document.value
    }
  }
}

# ── S3 VERSIONING ──────────────────────────────────────────────────────
# Requirements: 2.5, 2.6

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# ── S3 PUBLIC ACCESS BLOCK ─────────────────────────────────────────────
# Requirements: 2.1, 2.2

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = var.enable_cloudfront
  block_public_policy     = var.enable_cloudfront
  ignore_public_acls      = var.enable_cloudfront
  restrict_public_buckets = var.enable_cloudfront
}

# ── S3 BUCKET POLICY ───────────────────────────────────────────────────
# Requirements: 2.3, 2.4, 2.7, 2.8

# CloudFront OAC policy — grants s3:GetObject only to the CloudFront
# service principal scoped to this specific distribution ARN.
# Created only when CloudFront is enabled.
data "aws_iam_policy_document" "cf_oac" {
  count = var.enable_cloudfront ? 1 : 0

  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this[0].arn]
    }
  }
}

# Public-read policy — grants s3:GetObject to all principals with no
# condition, for use when CloudFront is disabled and the bucket serves
# content directly as a public S3 website.
# Created only when CloudFront is disabled.
data "aws_iam_policy_document" "public_read" {
  count = var.enable_cloudfront ? 0 : 1

  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

# Attach the correct policy to the bucket depending on CloudFront mode.
# depends_on ensures the public access block is applied first, which
# is required before a public bucket policy can be attached.
resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = var.enable_cloudfront ? data.aws_iam_policy_document.cf_oac[0].json : data.aws_iam_policy_document.public_read[0].json

  depends_on = [aws_s3_bucket_public_access_block.this]
}

# ── CLOUDFRONT OAC ─────────────────────────────────────────────────────
# Requirements: 3.9, 2.7

resource "aws_cloudfront_origin_access_control" "this" {
  count = var.enable_cloudfront ? 1 : 0

  name                              = var.bucket_name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ── CLOUDFRONT DISTRIBUTION ────────────────────────────────────────────
# Requirements: 3.1–3.10

resource "aws_cloudfront_distribution" "this" {
  count = var.enable_cloudfront ? 1 : 0

  origin {
    domain_name              = aws_s3_bucket.this.bucket_regional_domain_name
    origin_id                = var.bucket_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this[0].id
  }

  enabled             = true
  default_root_object = var.index_document
  aliases             = var.create_acm_certificate ? var.cloudfront_aliases : []
  price_class         = var.price_class
  tags                = var.tags

  default_cache_behavior {
    target_origin_id       = var.bucket_name
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # When local.create_acm is true, attach the validated ACM certificate with SNI.
  # When false, fall back to the default CloudFront certificate.
  # Exactly one of acm_certificate_arn / cloudfront_default_certificate must be set;
  # ternary expressions on each attribute satisfy that constraint in a single block.
  viewer_certificate {
    acm_certificate_arn            = local.create_acm ? aws_acm_certificate_validation.this[0].certificate_arn : null
    ssl_support_method             = local.create_acm ? "sni-only" : null
    minimum_protocol_version       = local.create_acm ? "TLSv1.2_2021" : null
    cloudfront_default_certificate = !local.create_acm
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

# ── ROUTE 53 HOSTED ZONE ───────────────────────────────────────────────
# Requirements: 5.1, 5.7

resource "aws_route53_zone" "this" {
  count = var.create_route53_zone ? 1 : 0

  name = var.domain_name
  tags = var.tags
}

# ── ACM CERTIFICATE ────────────────────────────────────────────────────
# Requirements: 4.1, 4.2

resource "aws_acm_certificate" "this" {
  count = local.create_acm ? 1 : 0

  provider = aws.us-east-1

  domain_name               = var.domain_name
  subject_alternative_names = var.cloudfront_aliases
  validation_method         = "DNS"
  tags                      = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# ── ACM VALIDATION DNS RECORDS ─────────────────────────────────────────
# Requirements: 4.3

resource "aws_route53_record" "acm_validation" {
  for_each = local.create_acm_validation ? {
    for dvo in aws_acm_certificate.this[0].domain_validation_options : dvo.domain_name => dvo
  } : {}

  zone_id = local.effective_zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 60
}

# ── ACM CERTIFICATE VALIDATION ─────────────────────────────────────────
# Requirements: 4.6

resource "aws_acm_certificate_validation" "this" {
  count = local.create_acm_validation ? 1 : 0

  provider = aws.us-east-1

  certificate_arn         = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]

  timeouts {
    create = "30m"
  }
}

# ── ROUTE 53 WEBSITE DNS RECORD ────────────────────────────────────────
# Requirements: 5.2–5.6

resource "aws_route53_record" "website" {
  count = local.zone_available ? 1 : 0

  zone_id = local.effective_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.enable_cloudfront ? aws_cloudfront_distribution.this[0].domain_name : aws_s3_bucket_website_configuration.this.website_endpoint
    zone_id                = var.enable_cloudfront ? aws_cloudfront_distribution.this[0].hosted_zone_id : aws_s3_bucket.this.hosted_zone_id
    evaluate_target_health = false
  }
}
