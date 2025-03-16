resource "aws_api_gateway_rest_api" "vpc_api" {
  name        = "vpc-api"
  description = "API for managing VPCs"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "vpc_resource" {
  rest_api_id = aws_api_gateway_rest_api.vpc_api.id
  parent_id   = aws_api_gateway_rest_api.vpc_api.root_resource_id
  path_part   = "vpc"
}

resource "aws_api_gateway_method" "create_vpc_method" {
  rest_api_id   = aws_api_gateway_rest_api.vpc_api.id
  resource_id   = aws_api_gateway_resource.vpc_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_auth.id

  depends_on = [aws_api_gateway_authorizer.cognito_auth]
}

resource "aws_api_gateway_integration" "create_vpc_integration" {
  rest_api_id             = aws_api_gateway_rest_api.vpc_api.id
  resource_id             = aws_api_gateway_resource.vpc_resource.id
  http_method             = aws_api_gateway_method.create_vpc_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.create_vpc.invoke_arn
  timeout_milliseconds    = var.api_gateway_timeout
}

resource "aws_api_gateway_deployment" "vpc_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.vpc_api.id

  # force redeployment for each change
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.vpc_api,
      aws_api_gateway_integration.create_vpc_integration,
      aws_api_gateway_integration.get_vpc_integration,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  description = "Deployed at ${timestamp()}"

  depends_on = [
    aws_api_gateway_integration.create_vpc_integration,
    aws_api_gateway_integration.get_vpc_integration,
  ]
}

resource "aws_lambda_permission" "apigw_create_vpc" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_vpc.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_resource" "vpc_id" {
  rest_api_id = aws_api_gateway_rest_api.vpc_api.id
  parent_id   = aws_api_gateway_resource.vpc_resource.id
  path_part   = "{vpc_id}"
}

resource "aws_api_gateway_method" "get_vpc_method" {
  rest_api_id   = aws_api_gateway_rest_api.vpc_api.id
  resource_id   = aws_api_gateway_resource.vpc_id.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_auth.id

  request_parameters = {
    "method.request.path.vpc_id" = true
  }

  depends_on = [aws_api_gateway_authorizer.cognito_auth]
}

resource "aws_api_gateway_integration" "get_vpc_integration" {
  rest_api_id             = aws_api_gateway_rest_api.vpc_api.id
  resource_id             = aws_api_gateway_resource.vpc_id.id
  http_method             = aws_api_gateway_method.get_vpc_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_vpc.invoke_arn
  timeout_milliseconds    = var.api_gateway_timeout

  request_parameters = {
    "integration.request.path.vpc_id" = "method.request.path.vpc_id"
  }
}

resource "aws_lambda_permission" "apigw_get_vpc" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_vpc.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.vpc_api.execution_arn}/*"
}

resource "aws_api_gateway_stage" "vpc_api_stage" {
  deployment_id = aws_api_gateway_deployment.vpc_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.vpc_api.id
  stage_name    = var.stage_name
}

resource "aws_api_gateway_method_settings" "apigw_settings" {
  rest_api_id = aws_api_gateway_rest_api.vpc_api.id
  stage_name  = aws_api_gateway_stage.vpc_api_stage.stage_name
  method_path = "*/*"

  settings {
    logging_level      = "INFO"
    metrics_enabled    = true
    data_trace_enabled = true
  }
}

resource "aws_api_gateway_authorizer" "cognito_auth" {
  name            = "cognito_auth"
  rest_api_id     = aws_api_gateway_rest_api.vpc_api.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [aws_cognito_user_pool.auth_pool.arn]
  identity_source = "method.request.header.Authorization"

  depends_on = [
    aws_api_gateway_rest_api.vpc_api,
    aws_cognito_user_pool.auth_pool
  ]
}

output "api_invoke_url" {
  value = aws_api_gateway_stage.vpc_api_stage.invoke_url
}
