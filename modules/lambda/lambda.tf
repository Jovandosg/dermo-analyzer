# Lambda Module: modules/lambda/main.tf

variable "function_name" {
  description = "Name for the Lambda function."
  type        = string
}

variable "project_name" {
  description = "Project name for tagging resources."
  type        = string
}

variable "handler" {
  description = "The function entrypoint in your code."
  type        = string
}

variable "runtime" {
  description = "The runtime environment for the Lambda function."
  type        = string
}

variable "iam_role_arn" {
  description = "ARN of the IAM role for the Lambda function."
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket, used for environment variables or triggers."
  type        = string
}

variable "environment_variables" {
  description = "A map of environment variables for the Lambda function."
  type        = map(string)
  default     = {}
}

variable "timeout" {
  description = "The amount of time that Lambda allows a function to run before stopping it."
  type        = number
  default     = 30 # Seconds
}

variable "memory_size" {
  description = "The amount of memory available to the function at runtime."
  type        = number
  default     = 256 # MB
}

variable "source_code_path" {
  description = "Path to the Lambda function's deployment package (ZIP file)."
  type        = string
  default     = "../lambda_package/image_analysis.zip" # Placeholder, will need actual package
}

# Create a dummy zip file for now, this should be replaced by the actual build artifact
# In a real CI/CD pipeline, this zip file would be created by a build process.
resource "null_resource" "create_dummy_lambda_package" {
  # Only create if the file doesn't exist to avoid re-creating on every apply
  # This is a HACK for local development. In a real setup, the zip is an artifact.
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    # Create a directory for the lambda package if it doesn't exist
    # Create a dummy index.js and zip it
    command = <<EOT
      mkdir -p ../lambda_package
      if [ ! -f ../lambda_package/image_analysis.zip ]; then
        echo 'exports.handler = async (event) => { console.log("Hello from dummy Lambda!"); return { statusCode: 200, body: JSON.stringify("Dummy response") }; };' > ../lambda_package/index.js
        cd ../lambda_package && zip -r image_analysis.zip index.js && cd -
      fi
    EOT
    working_dir = path.module # Run from the module's directory
  }
}



resource "aws_lambda_function" "this" {
  function_name = var.function_name
  handler       = var.handler
  runtime       = var.runtime
  role          = var.iam_role_arn
  timeout       = var.timeout
  memory_size   = var.memory_size

  # The source_code_hash and filename will come from the actual deployment package
  # For now, using a placeholder. This needs to be updated when the Node.js code is ready.
  filename         = var.source_code_path 
  source_code_hash = filebase64sha256(var.source_code_path)
  # This dependency ensures the dummy zip is created before lambda tries to use it.
  # In a real scenario, the zip file is an input artifact.
  depends_on = [null_resource.create_dummy_lambda_package]


  environment {
    variables = var.environment_variables
  }

  tags = {
    Name    = "${var.project_name}-lambda-${var.function_name}"
    Project = var.project_name
  }
}

# CloudWatch Log Group for the Lambda function
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14 # Or make this a variable

  tags = {
    Name    = "${var.project_name}-log-group-${var.function_name}"
    Project = var.project_name
  }
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function."
  value       = aws_lambda_function.this.arn
}

output "lambda_function_name" {
  description = "The name of the Lambda function."
  value       = aws_lambda_function.this.function_name
}

output "lambda_invoke_arn" {
  description = "The Invoke ARN of the Lambda function."
  value       = aws_lambda_function.this.invoke_arn
}

