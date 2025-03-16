resource "aws_cognito_user_pool" "auth_pool" {
  name = "vpc-api-user-pool"
}

resource "aws_cognito_user_pool_client" "client" {
  name                = "vpc-api-client"
  user_pool_id        = aws_cognito_user_pool.auth_pool.id
  generate_secret     = false
  explicit_auth_flows = ["USER_PASSWORD_AUTH"]
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.auth_pool.id
}

output "cognito_user_pool_client_id" {
  value = aws_cognito_user_pool_client.client.id
}
