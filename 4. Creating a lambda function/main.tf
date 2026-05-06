terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 6.0"
    }
  }
}

provider "aws" {
    region = "us-east-1"
}

# IAM: trust policy document
# Defines WHO can assume this role.
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# IAM: permissions policy document for DynamoDB
# Defines WHAT the role can do once assumed.
data "aws_iam_policy_document" "lambda_dynamodb_policy" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:UpdateItem"
      ]

    resources = [aws_dynamodb_table.visitor_counter_table.arn]
  }
}

# IAM: the role itself
# Creates the role in AWS with its trust policy.
resource "aws_iam_role" "db_update_lambda_role" {
  name               = "db_update_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# IAM: managed policy attachment for CloudWatch Logs
# AWSLambdaBasicExecutionRole is an AWS-managed policy that grants the three
# log actions a Lambda needs: CreateLogGroup, CreateLogStream, PutLogEvents.
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" { 
  role       = aws_iam_role.db_update_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM: inline policy for DynamoDB
# aws_iam_role_policy creates an INLINE policy — one that lives on this role
# and only this role.
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name   = "lambda_dynamodb_access"
  role   = aws_iam_role.db_update_lambda_role.id
  policy = data.aws_iam_policy_document.lambda_dynamodb_policy.json
}

# Package the Lambda function code
data "archive_file" "db_update_fn" {
  type        = "zip"
  source_file = "${path.module}/db_update_fn.py"
  output_path = "${path.module}/db_update_fn.zip"
}

# Lambda function
resource "aws_lambda_function" "db_update_fn" {
  filename           = data.archive_file.db_update_fn.output_path
  function_name      = "db_update_fn"
  role               = aws_iam_role.db_update_lambda_role.arn
  handler            = "db_update_fn.lambda_handler" # The handler is the entry point for the Lambda function, in the format "file_name.function_name"
  code_sha256        = data.archive_file.db_update_fn.output_base64sha256
  runtime            = "python3.14"
  reserved_concurrent_executions = 1 # Limit to 1 concurrent execution

  tags = {
    Environment = "production"
    Application = "CRC"
  }
}

resource "aws_cloudwatch_log_group" "db_update_fn" {
    name              = "/aws/lambda/${aws_lambda_function.db_update_fn.function_name}"
    retention_in_days = 14
}