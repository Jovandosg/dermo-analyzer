# IAM Module: modules/iam/main.tf

variable "project_name" {
  description = "Project name for tagging resources and naming roles."
  type        = string
}

variable "s3_image_bucket_arn" {
  description = "ARN of the S3 bucket for images to grant Lambda access."
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function that will use this role."
  type        = string
}

# IAM Role for Lambda Function
resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project_name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-lambda-exec-role"
    Project = var.project_name
  }
}

# IAM Policy for Lambda to access S3, Bedrock, and CloudWatch Logs
resource "aws_iam_policy" "lambda_permissions" {
  name        = "${var.project_name}-lambda-permissions-policy"
  description = "Policy for Lambda to access S3, Bedrock, and CloudWatch Logs"

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action   = [
          "s3:GetObject",
          "s3:PutObject", # If Lambda needs to write results back or for presigned URL generation if done in Lambda
          "s3:ListBucket" # If needed for listing objects
        ],
        Effect   = "Allow",
        Resource = [
          var.s3_image_bucket_arn,
          "${var.s3_image_bucket_arn}/*" # Access to objects within the bucket
        ]
      },
      {
        Action   = "bedrock:InvokeModel",
        Effect   = "Allow",
        Resource = "*" # Restrict this to specific model ARNs in a production environment
      },
      {
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*" # Restrict to specific log groups if possible
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-lambda-permissions-policy"
    Project = var.project_name
  }
}

# Attach policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_permissions_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_permissions.arn
}

# Output for the Lambda execution role ARN
output "lambda_exec_role_arn" {
  description = "The ARN of the IAM role for Lambda execution."
  value       = aws_iam_role.lambda_exec_role.arn
}

output "lambda_exec_role_name" {
  description = "The Name of the IAM role for Lambda execution."
  value       = aws_iam_role.lambda_exec_role.name
}

