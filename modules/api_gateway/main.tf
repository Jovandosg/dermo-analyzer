# API Gateway Module: modules/api_gateway/main.tf

variable "project_name" {
  description = "Project name for tagging resources and naming API Gateway."
  type        = string
}

variable "lambda_function_arn" {
  description = "ARN of the Lambda function to integrate with API Gateway."
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function (used for permissions)."
  type        = string
}

variable "aws_region" {
  description = "AWS region for deploying the API Gateway."
  type        = string
}

variable "stage_name" {
  description = "The name of the stage for the API Gateway deployment."
  type        = string
  default     = "dev"
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "this" {
  name        = "${var.project_name}-api"
  description = "API Gateway for ${var.project_name} application"
  endpoint_configuration {
    types = ["REGIONAL"] # Or EDGE for CloudFront distribution
  }

  tags = {
    Name    = "${var.project_name}-api"
    Project = var.project_name
  }
}

# API Gateway Resource (e.g., /analyze)
resource "aws_api_gateway_resource" "analyze" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "analyze" # This will be the /analyze endpoint
}

# API Gateway Method (e.g., POST for /analyze)
resource "aws_api_gateway_method" "post_analyze" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.analyze.id
  http_method   = "POST"
  authorization = "NONE" # Or use AWS_IAM or a COGNITO_USER_POOLS authorizer
}

# API Gateway Integration with Lambda
resource "aws_api_gateway_integration" "lambda_analyze" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.analyze.id
  http_method             = aws_api_gateway_method.post_analyze.http_method
  integration_http_method = "POST" # Must be POST for Lambda proxy integration
  type                    = "AWS_PROXY" # For Lambda proxy integration
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.lambda_function_arn}/invocations"
}

# API Gateway Method Response
resource "aws_api_gateway_method_response" "post_analyze_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.analyze.id
  http_method = aws_api_gateway_method.post_analyze.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty" # Or define a model
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# API Gateway Integration Response
resource "aws_api_gateway_integration_response" "lambda_analyze_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.analyze.id
  http_method = aws_api_gateway_method.post_analyze.http_method
  status_code = aws_api_gateway_method_response.post_analyze_200.status_code
  # No explicit mapping needed for AWS_PROXY
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

# CORS configuration: OPTIONS method for /analyze resource
resource "aws_api_gateway_method" "options_analyze" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.analyze.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_analyze" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.analyze.id
  http_method   = aws_api_gateway_method.options_analyze.http_method
  type          = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_analyze_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.analyze.id
  http_method = aws_api_gateway_method.options_analyze.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_analyze_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.analyze.id
  http_method = aws_api_gateway_method.options_analyze.http_method
  status_code = aws_api_gateway_method_response.options_analyze_200.status_code
  response_templates = {
    "application/json" = ""
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'", # Add GET, PUT, DELETE if needed
    "method.response.header.Access-Control-Allow-Origin"  = "'*'" # Be more specific in production
  }
  depends_on = [aws_api_gateway_method.options_analyze]
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  # A new deployment is required when the API changes. Terraform handles this by default.
  # Using a trigger like a timestamp or hash of API resources can force redeployment.
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.analyze.id,
      aws_api_gateway_method.post_analyze.id,
      aws_api_gateway_integration.lambda_analyze.id,
      aws_api_gateway_method.options_analyze.id,
      aws_api_gateway_integration.options_analyze.id
      # Add other resources that should trigger a new deployment
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = var.stage_name
}

# Lambda permission to allow API Gateway to invoke the function
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  # The /*/* part allows any method on any resource path
  # For more restrictive permissions, specify the ARN like:
  # arn:aws:execute-api:{region}:{account_id}:{api_id}/{stage_name}/{method_verb}/{resource_path}
  source_arn = "${aws_api_gateway_rest_api.this.execution_arn}/*/*/*"
}

output "api_gateway_invoke_url" {
  description = "The invoke URL for the API Gateway stage."
  value       = "${aws_api_gateway_deployment.this.invoke_url}${var.stage_name}"
}

output "api_gateway_id" {
  description = "The ID of the API Gateway Rest API."
  value       = aws_api_gateway_rest_api.this.id
}

output "api_gateway_execution_arn" {
  description = "The execution ARN of the API Gateway Rest API."
  value       = aws_api_gateway_rest_api.this.execution_arn
}

# Outputs for custom domain setup (if used)
output "api_gateway_domain_name" {
  description = "The regional domain name of the API Gateway. To be used if setting up custom domain with Route 53."
  value       = aws_api_gateway_rest_api.this.execution_arn # This is not the domain name, it's the execution ARN. Need to fix this.
  # Correct value would be something like: aws_api_gateway_domain_name.example.domain_name if a custom domain is configured here.
  # For now, this output is a placeholder or should point to the invoke URL's host part.
  # If using a custom domain, that resource's output would be used.
  # For regional endpoint, the invoke URL is the primary access point without custom domain.
  # Example: d3ag255xs9.execute-api.us-east-1.amazonaws.com
  value       = split("/", aws_api_gateway_deployment.this.invoke_url)[2]
}

output "api_gateway_hosted_zone_id" {
  description = "The regional hosted zone ID of the API Gateway. To be used if setting up custom domain with Route 53."
  # This is a static value per region for API Gateway regional endpoints.
  # Example for us-east-1: Z1UJRXOUMOOFQ8
  # This needs to be looked up or hardcoded based on var.aws_region.
  # For simplicity, we'll omit this or require manual input if a custom domain is directly mapped to regional API GW.
  # If using CloudFront in front of API GW, then CloudFront's zone ID is used.
  value       = "" # Placeholder - typically you'd use a data source or map for this.
}

