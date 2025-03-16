data "archive_file" "create_vpc_zip" {
  type        = "zip"
  output_path = "/tmp/create_vpc.zip"
  source {
    content  = file("create_vpc.py")
    filename = "create_vpc.py"
  }
}

data "archive_file" "get_vpc_zip" {
  type        = "zip"
  output_path = "/tmp/get_vpc.zip"
  source {
    content  = file("get_vpc.py")
    filename = "get_vpc.py"
  }
}

resource "aws_lambda_function" "create_vpc" {
  function_name = "create_vpc"
  runtime       = var.lambda_runtime
  handler       = "create_vpc.lambda_handler"
  role          = aws_iam_role.lambda_exec.arn
  timeout       = var.lambda_timeout

  filename         = data.archive_file.create_vpc_zip.output_path
  source_code_hash = data.archive_file.create_vpc_zip.output_base64sha256

  depends_on = [
    aws_iam_role.lambda_exec,
    aws_dynamodb_table.vpc_resources
  ]

  environment {
    variables = {
      LOG_LEVEL      = "INFO",
      DYNAMODB_TABLE = aws_dynamodb_table.vpc_resources.name
    }
  }
}

resource "aws_lambda_function" "get_vpc" {
  function_name = "get_vpc"
  runtime       = var.lambda_runtime
  handler       = "get_vpc.lambda_handler"
  role          = aws_iam_role.lambda_exec.arn
  timeout       = var.lambda_timeout

  filename         = data.archive_file.get_vpc_zip.output_path
  source_code_hash = data.archive_file.get_vpc_zip.output_base64sha256

  depends_on = [
    aws_iam_role.lambda_exec,
    aws_dynamodb_table.vpc_resources
  ]

  environment {
    variables = {
      LOG_LEVEL      = "INFO",
      DYNAMODB_TABLE = aws_dynamodb_table.vpc_resources.name
    }
  }
}

data "archive_file" "authorizer_zip" {
  type        = "zip"
  output_path = "/tmp/authorizer.zip"
  source {
    content  = file("authorizer.py")
    filename = "authorizer.py"
  }
}

resource "aws_lambda_function" "api_authorizer" {
  function_name = "api_authorizer"
  runtime       = var.lambda_runtime
  handler       = "authorizer.lambda_handler"
  role          = aws_iam_role.lambda_exec.arn
  timeout       = var.lambda_authorizer_timeout

  filename         = data.archive_file.authorizer_zip.output_path
  source_code_hash = data.archive_file.authorizer_zip.output_base64sha256

  environment {
    variables = {
      MY_AWS_REGION        = var.aws_region
      COGNITO_USER_POOL_ID = aws_cognito_user_pool.auth_pool.id
      COGNITO_CLIENT_ID    = aws_cognito_user_pool_client.client.id
    }
  }
}
