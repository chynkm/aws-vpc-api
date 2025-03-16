variable "aws_region" {
  type        = string
  description = "The AWS region for creating the resources"
  default     = "us-east-1"
}

variable "aws_profile" {
  type        = string
  description = "The AWS profile to be used for creating the resources"
  default     = "km"
}

variable "lambda_runtime" {
  type        = string
  description = "The Python runtime version"
  default     = "python3.9"
}

variable "lambda_timeout" {
  type        = string
  description = "The AWS Lambda timeout, should be less than API Gateway timeout"
  default     = 25
}

variable "lambda_authorizer_timeout" {
  type        = string
  description = "The API Gateway authorizer timeout"
  default     = 10
}
