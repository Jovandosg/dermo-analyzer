# Route53 Module: modules/route53/main.tf

variable "domain_name" {
  description = "The domain name to configure in Route 53 (e.g., cloudzen.com.br)."
  type        = string
}

variable "project_name" {
  description = "Project name for tagging resources."
  type        = string
}

# Optional: Variables for API Gateway and CloudFront if creating A records here
variable "api_gateway_domain_name" {
  description = "The target domain name of the API Gateway (e.g., custom domain or regional endpoint)."
  type        = string
  default     = ""
}

variable "api_gateway_zone_id" {
  description = "The hosted zone ID of the API Gateway target."
  type        = string
  default     = ""
}

variable "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution."
  type        = string
  default     = ""
}

variable "cloudfront_zone_id" {
  description = "The hosted zone ID of the CloudFront distribution (this is a static value for CloudFront)."
  type        = string
  default     = "Z2FDTNDATAQYW2" # Default CloudFront hosted zone ID
}

# Get the existing Route 53 hosted zone for the domain_name
# This assumes the hosted zone is already created in AWS. If not, it needs to be created.
# For this project, the user stated the domain exists but needs configuration.
# We will create a new zone if one is not found, or use an existing one.

data "aws_route53_zone" "selected" {
  # If private_zone is not set to true, it will look for a public zone.
  name         = "${var.domain_name}." # Zone names have a trailing dot
  private_zone = false
}

resource "aws_route53_zone" "this" {
  count = data.aws_route53_zone.selected.zone_id == "" ? 1 : 0 # Create only if not found
  name  = var.domain_name

  tags = {
    Name    = "${var.project_name}-zone-${var.domain_name}"
    Project = var.project_name
  }
}

locals {
  zone_id = data.aws_route53_zone.selected.zone_id == "" ? aws_route53_zone.this[0].zone_id : data.aws_route53_zone.selected.zone_id
  # Name servers will be available if a new zone is created
  name_servers = data.aws_route53_zone.selected.zone_id == "" ? aws_route53_zone.this[0].name_servers : data.aws_route53_zone.selected.name_servers
}

# Example A record for the root domain pointing to CloudFront (for frontend)
resource "aws_route53_record" "frontend_root" {
  count   = var.cloudfront_domain_name != "" ? 1 : 0
  zone_id = local.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# Example A record for www subdomain pointing to CloudFront (for frontend)
resource "aws_route53_record" "frontend_www" {
  count   = var.cloudfront_domain_name != "" ? 1 : 0
  zone_id = local.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# Example A record for API Gateway (e.g., api.cloudzen.com.br)
# This requires a custom domain to be configured for API Gateway first.
# The api_gateway_domain_name and api_gateway_zone_id would come from that setup.
resource "aws_route53_record" "api" {
  count   = var.api_gateway_domain_name != "" && var.api_gateway_zone_id != "" ? 1 : 0
  zone_id = local.zone_id
  name    = "api.${var.domain_name}" # Example: api.cloudzen.com.br
  type    = "A"

  alias {
    name                   = var.api_gateway_domain_name
    zone_id                = var.api_gateway_zone_id
    evaluate_target_health = false # Set to true if health checks are configured
  }
}

output "zone_id" {
  description = "The ID of the Route 53 hosted zone."
  value       = local.zone_id
}

output "name_servers" {
  description = "Name servers for the hosted zone. These need to be configured at your domain registrar if a new zone was created."
  value       = local.name_servers
}

