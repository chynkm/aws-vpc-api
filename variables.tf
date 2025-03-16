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
