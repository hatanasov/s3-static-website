# ── INPUT VARIABLES ────────────────────────────────────────────────────

# Requirement 6.1
variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket. Must comply with AWS S3 naming constraints: 3–63 characters, lowercase alphanumeric characters and hyphens only, no leading or trailing hyphens, and must not be an IPv4 address."

  #The following validation is not required. For static website the name of the bucket mus match the domain name! 
  # validation {
  #   condition = (
  #     length(var.bucket_name) >= 3 &&
  #     length(var.bucket_name) <= 63 &&
  #     can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.bucket_name)) &&
  #     !can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.bucket_name))
  #   )
  #   error_message = "bucket_name must be 3–63 lowercase alphanumeric characters or hyphens, no leading/trailing hyphens, and not an IPv4 address."
  # }
}

# Requirement 6.2
variable "index_document" {
  type        = string
  description = "The name of the index document served when a request targets a directory. Must be a filename with a .html extension (1–255 characters)."
  default     = "index.html"
}

# Requirement 6.3
variable "error_document" {
  type        = string
  description = "The name of the error document served when a requested object is not found. Must be a filename with a .html extension (1–255 characters), or an empty string to omit."
  default     = "error.html"
}

# Requirement 6.4
variable "force_destroy" {
  type        = bool
  description = "When true, allows the bucket to be deleted even if it contains objects. When false, deletion is rejected if the bucket is non-empty."
  default     = false
}

# Requirement 6.5
variable "enable_versioning" {
  type        = bool
  description = "When true, enables S3 object versioning (status = Enabled). When false, versioning is set to Suspended."
  default     = false
}

# Requirement 6.6
variable "enable_cloudfront" {
  type        = bool
  description = "When true, creates a CloudFront distribution with OAC in front of the S3 bucket and sets the bucket to private. When false, the bucket is publicly accessible via S3 website hosting."
  default     = false
}

# Requirement 6.7
variable "price_class" {
  type        = string
  description = "The CloudFront price class that controls which edge locations serve content. Accepted values: PriceClass_100, PriceClass_200, PriceClass_All."
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be one of: PriceClass_100, PriceClass_200, PriceClass_All."
  }
}

# Requirement 6.8
variable "cloudfront_aliases" {
  type        = list(string)
  description = "List of alternate domain names (CNAMEs) for the CloudFront distribution. Requires enable_cloudfront = true and create_acm_certificate = true."
  default     = []
}

# Requirement 6.9
variable "create_acm_certificate" {
  type        = bool
  description = "When true, creates an ACM certificate in us-east-1 for the domain_name and attaches it to the CloudFront distribution. Requires enable_cloudfront = true and a non-empty domain_name."
  default     = false
}

# Requirement 6.10
variable "domain_name" {
  type        = string
  description = "The custom domain name for the website. Required when create_acm_certificate = true or cloudfront_aliases is non-empty. Used for ACM certificate issuance, Route 53 zone creation, and DNS records."
  default     = ""
}

# Requirement 6.11
variable "create_route53_zone" {
  type        = bool
  description = "When true, creates a new Route 53 hosted zone for the domain_name. When false, an existing zone identified by route53_zone_id is used if provided."
  default     = false
}

# Requirement 6.12
variable "route53_zone_id" {
  type        = string
  description = "The ID of an existing Route 53 hosted zone to use for DNS records and ACM validation. Ignored when create_route53_zone = true."
  default     = ""
}

# Requirement 6.13
variable "tags" {
  type        = map(string)
  description = "A map of key-value tags to apply to all AWS resources created by this module."
  default     = {}
}
