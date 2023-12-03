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
  function_name = "MyLambdaFunction"
  role          = aws_iam_role.lambda_execution_role.arn

  # Assuming your Python code is in a file named lambda_function.py
  filename         = data.archive_file.main_lambda_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.main_lambda_zip.output_path)
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.10"
  publish          = true
}

# resource "aws_lambda_alias" "live" {
#   name             = "live"
#   description      = "Live alias"
#   function_name    = aws_lambda_function.main_lambda.function_name
#   function_version = aws_lambda_function.main_lambda.version
# }

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
  name             = "MyLambdaCodeDeployApp"
  compute_platform = "Lambda"
}

# CodeDeploy Deployment Group
resource "aws_codedeploy_deployment_group" "lambda_deployment_group" {
  app_name               = aws_codedeploy_app.lambda_codedeploy_app.name
  deployment_group_name  = "MyLambdaDeploymentGroup"
  deployment_config_name = "CodeDeployDefault.LambdaAllAtOnce"

  service_role_arn = aws_iam_role.example.arn

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

}

# # SNS topic for deployment notifications
# resource "aws_sns_topic" "lambda_deployment_notifications" {
#   name = "lambda-deployment-notifications"
# }



# - name: Create CodeDeploy Deployment
#   run: |
#     aws deploy create-deployment --application-name [Your_Application_Name] --deployment-config-name CodeDeployDefault.LambdaAllAtOnce --deployment-group-name [Your_Deployment_Group_Name] --description "Lambda Deployment" --s3-location bucket=[Your_Bucket],bundleType=zip,key=[Your_Lambda_Zip],version=[Your_Version]


output "current_version" {
  value = aws_lambda_function.main_lambda.version
}
