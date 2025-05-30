# Terraform Configuration for AWS Provider

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# Root module calling other modules
module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  aws_region   = var.aws_region
  vpc_cidr     = var.vpc_cidr
  public_sn_count = var.public_sn_count
  private_sn_count = var.private_sn_count
}

module "s3_bucket_images" {
  source      = "./modules/s3"
  bucket_name = var.s3_image_bucket_name
  project_name = var.project_name
  # Add other necessary variables like ACL, versioning, CORS etc.
}

module "iam" {
  source                 = "./modules/iam"
  project_name           = var.project_name
  s3_image_bucket_arn    = module.s3_bucket_images.s3_bucket_arn
  lambda_function_name   = "${var.project_name}-image-analysis-lambda" # Example name
}

module "lambda_image_analysis" {
  source                 = "./modules/lambda"
  function_name          = "${var.project_name}-image-analysis-lambda"
  project_name           = var.project_name
  handler                = "index.handler" # Placeholder, will be defined by Node.js code
  runtime                = "nodejs18.x"    # Or other supported Node.js runtime
  iam_role_arn           = module.iam.lambda_exec_role_arn
  s3_bucket_name         = var.s3_image_bucket_name
  # Environment variables for Bedrock model, etc.
  environment_variables = {
    BEDROCK_MODEL_ID = var.bedrock_model_id
    S3_BUCKET_NAME   = var.s3_image_bucket_name
  }
  # Add layers, VPC config if needed
}

module "api_gateway" {
  source               = "./modules/api_gateway"
  project_name         = var.project_name
  lambda_function_arn  = module.lambda_image_analysis.lambda_function_arn
  lambda_function_name = module.lambda_image_analysis.lambda_function_name # For invoke permission
  aws_region           = var.aws_region
  # stage_name, etc.
}

module "acm" {
  source                 = "./modules/acm"
  domain_name            = var.domain_name
  alternative_names      = ["www.${var.domain_name}"]
  route53_zone_id        = module.route53.zone_id # Required for DNS validation
}

module "frontend_hosting" {
  source                 = "./modules/frontend_hosting"
  project_name           = var.project_name
  domain_name            = var.domain_name
  # S3 bucket for static site, CloudFront distribution
  # Pass ACM certificate ARN from acm module
  acm_certificate_arn    = module.acm.certificate_arn
  # Origin Access Identity for S3 bucket
  # Route 53 alias record details
  route53_zone_id        = module.route53.zone_id
}

module "route53" {
  source      = "./modules/route53"
  domain_name = var.domain_name
  # Records for API Gateway and CloudFront will be added here or within respective modules
  # For example, alias for CloudFront from frontend_hosting module output
  # and alias for API Gateway from api_gateway module output
  cloudfront_domain_name = module.frontend_hosting.cloudfront_domain_name
  cloudfront_zone_id     = module.frontend_hosting.cloudfront_hosted_zone_id
  api_gateway_domain_name = module.api_gateway.api_gateway_domain_name # This would be the custom domain if set up
  api_gateway_zone_id     = module.api_gateway.api_gateway_hosted_zone_id # This would be the custom domain zone id if set up
}

