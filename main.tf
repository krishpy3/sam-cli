provider "aws" {
  region  = "us-east-1"
  profile = "denis"
}

# s3 backend
terraform {
  backend "s3" {
    bucket = "krish-denis"
    key    = "lambda-deployment/terraform.tfstate"
    region = "us-east-1"
  }
}

variable "function_name" {
  default = "MyLambdaFunction"
}

variable "code_deploy_app_name" {
  default = "MyLambdaCodeDeployApp"
}

variable "deployment_group_name" {
  default = "MyLambdaDeploymentGroup"
}

# IAM role for the Lambda function
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "lambda_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Action = [
            "codedeploy:PutLifecycleEventHookExecutionStatus"
          ],
          Effect   = "Allow",
          Resource = "*"
        }
      ]
    })
  }
}

resource "aws_iam_role_policy_attachment" "lambda_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function
data "archive_file" "main_lambda_zip" {
  type        = "zip"
  source_file = "lambda/myDateTimeFunction.py"
  output_path = ".tmp/myDateTimeFunction.zip"
}
resource "aws_lambda_function" "main_lambda" {
  function_name = var.function_name
  role          = aws_iam_role.lambda_execution_role.arn

  # Assuming your Python code is in a file named lambda_function.py
  filename         = data.archive_file.main_lambda_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.main_lambda_zip.output_path)
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.10"
  publish          = true
}


# Pre traffic hook
data "archive_file" "pre_hook_zip" {
  type        = "zip"
  source_file = "lambda/beforeAllowTraffic.py"
  output_path = ".tmp/beforeAllowTraffic.zip"
}
resource "aws_lambda_function" "pre_traffic_hook" {
  function_name = "PreTrafficHook"
  role          = aws_iam_role.lambda_execution_role.arn

  filename         = data.archive_file.pre_hook_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.pre_hook_zip.output_path)
  handler          = "pre_hook.lambda_handler"
  runtime          = "python3.8"
  environment {
    variables = {
      NewVersion = "${aws_lambda_function.main_lambda.arn}:${aws_lambda_function.main_lambda.version}"
    }
  }
}


# Post traffic hook
data "archive_file" "post_hook_zip" {
  type        = "zip"
  source_file = "lambda/afterAllowTraffic.py"
  output_path = ".tmp/afterAllowTraffic.zip"
}
resource "aws_lambda_function" "post_traffic_hook" {
  function_name = "PostTrafficHook"
  role          = aws_iam_role.lambda_execution_role.arn

  filename         = data.archive_file.post_hook_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.post_hook_zip.output_path)
  handler          = "post_hook.lambda_handler"
  runtime          = "python3.8"

  environment {
    variables = {
      NewVersion = "${aws_lambda_function.main_lambda.arn}:${aws_lambda_function.main_lambda.version}"
    }
  }
}


data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "example" {
  name               = "example-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda"
  role       = aws_iam_role.example.name
}

# CodeDeploy Application
resource "aws_codedeploy_app" "lambda_codedeploy_app" {
  name             = var.code_deploy_app_name
  compute_platform = "Lambda"
}

# CodeDeploy Deployment Group
resource "aws_codedeploy_deployment_group" "lambda_deployment_group" {
  app_name               = aws_codedeploy_app.lambda_codedeploy_app.name
  deployment_group_name  = var.deployment_group_name
  deployment_config_name = "CodeDeployDefault.LambdaAllAtOnce"

  service_role_arn = aws_iam_role.example.arn

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

}

output "current_version" {
  value = aws_lambda_function.main_lambda.version
}

data "aws_lambda_alias" "live_version" {
  name          = "live"
  function_name = aws_lambda_function.main_lambda.function_name
}

output "live_version" {
  value = data.aws_lambda_alias.live_version.function_version
}
