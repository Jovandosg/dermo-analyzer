# Terraform Variables Configuration

variable "aws_region" {
  description = "AWS region to deploy resources."
  type        = string
  default     = "us-east-1" # Or any other preferred region
}

variable "project_name" {
  description = "A unique name for the project to prefix resources."
  type        = string
  default     = "dermo-analyzer"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_sn_count" {
  description = "Number of public subnets to create."
  type        = number
  default     = 2
}

variable "private_sn_count" {
  description = "Number of private subnets to create."
  type        = number
  default     = 2
}

variable "s3_image_bucket_name" {
  description = "Name for the S3 bucket to store uploaded images. Must be globally unique."
  type        = string
  # Default will be constructed to ensure uniqueness, e.g., using project_name and random suffix
  # For now, let's ask the user or generate it dynamically in a real scenario.
  # For this example, let's make it configurable.
  # default     = "dermo-analyzer-images-bucket"
}

variable "bedrock_model_id" {
  description = "The ID of the Amazon Bedrock model to be used for image analysis."
  type        = string
  default     = "anthropic.claude-3-sonnet-20240229-v1:0" # Example, user should confirm or change
}

variable "domain_name" {
  description = "The custom domain name for the application (e.g., cloudzen.com.br)."
  type        = string
  default     = "cloudzen.com.br"
}

