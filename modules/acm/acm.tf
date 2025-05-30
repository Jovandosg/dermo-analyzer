# ACM Module: modules/acm/main.tf

variable "domain_name" {
  description = "The domain name for which the certificate will be issued (e.g., cloudzen.com.br)."
  type        = string
}

variable "alternative_names" {
  description = "A list of alternative domain names (e.g., [\"www.cloudzen.com.br\"])."
  type        = list(string)
  default     = []
}

variable "route53_zone_id" {
  description = "The ID of the Route 53 hosted zone to use for DNS validation."
  type        = string
}

variable "project_name" {
  description = "Project name for tagging resources."
  type        = string
}

resource "aws_acm_certificate" "this" {
  domain_name       = var.domain_name
  subject_alternative_names = var.alternative_names
  validation_method = "DNS"

  tags = {
    Name    = "${var.project_name}-cert-${var.domain_name}"
    Project = var.project_name
  }

  # Ensure the certificate is created before attempting validation
  lifecycle {
    create_before_destroy = true
  }
}

# DNS records for validation
# This creates CNAME records in the specified Route 53 zone to validate the certificate.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true # Useful if a record with the same name already exists
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

# Certificate Validation resource
# This resource waits for the DNS records to propagate and for ACM to validate the certificate.
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

output "certificate_arn" {
  description = "The ARN of the validated ACM certificate."
  value       = aws_acm_certificate_validation.this.certificate_arn # Use the validation resource ARN
}

output "certificate_status" {
  description = "The status of the ACM certificate."
  value       = aws_acm_certificate.this.status
}

