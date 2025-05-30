# VPC Module: modules/vpc/main.tf

variable "project_name" {
  description = "Project name for tagging resources."
  type        = string
}

variable "aws_region" {
  description = "AWS region for the VPC."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "public_sn_count" { 
  description = "Number of public subnets"
  type = number
}

variable "private_sn_count" {
  description = "Number of private subnets"
  type = number
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, max(var.public_sn_count, var.private_sn_count))
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Project     = var.project_name
    Environment = "dev" # Or make this a variable
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

resource "aws_subnet" "public" {
  count                   = var.public_sn_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-public-subnet-${count.index + 1}"
    Project = var.project_name
    Tier    = "Public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "public" {
  count          = var.public_sn_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private" {
  count                   = var.private_sn_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + var.public_sn_count) # Ensure CIDR blocks don't overlap
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name    = "${var.project_name}-private-subnet-${count.index + 1}"
    Project = var.project_name
    Tier    = "Private"
  }
}

# NAT Gateway (Optional, for private subnets to access internet)
# For simplicity in this demo, we might not need full private subnets with NAT
# If Lambda needs internet access and is in a private subnet, NAT Gateway is required.
# For now, assuming Lambda can be in public subnets or use VPC endpoints for AWS services.

# Outputs for the VPC module
output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets."
  value       = aws_subnet.private[*].id
}

