# AWS VPC API

Creating an AWS VPC using serverless tools.


## Install Git Pre-commit hooks

Install pre-commit by executing the following command in Linux and Mac:

```
pip install pre-commit
```

Initialize pre-commit inside the repo by executing the following command:

```
pre-commit install
```

This will enable the pre-commit to run automatically on git commit!
Please refer this [link](https://pre-commit.com/) for a detailed introduction.


## Prerequisites

- An AWS account with necessary permissions.
- AWS CLI installed and configured with appropriate credentials.
- Terraform preferably configured using [tfenv](https://github.com/tfutils/tfenv).
- [jq](https://jqlang.org/)


## Assumptions and other informations

- This code is designed to support IPv4 subnets only.
- An AWS account supports a maximum limit of 5 VPCs by default.
- AWS allows VPCs with [CIDR blocks](https://docs.aws.amazon.com/vpc/latest/userguide/subnet-sizing.html#subnet-sizing-ipv4) in the range of `/16` to `/28`.


## Terraform setup

The repo can be deployed using Terraform.


Create the plans directory

```
mkdir plans
```

Configure the AWS profile and other variables in the `variables.tf` file.
Execute the following command to initialize terraform and for downloading the necessary providers.

```
terraform init
```

Create the terraform plan and apply it. This will create the necessary AWS resources.

```
terraform plan -out plans/aws-api
terraform apply plans/aws-api
```

The last command will output necessary values that will be required for the next step.


## Cognito authentication

Create a new user in Cognito using the following commands, replace the value `cognito_user_pool_id` from the Terraform output. Please also replace the values for `aws-profile-name` and `aws-region`:

```
aws cognito-idp admin-create-user \
  --user-pool-id <cognito_user_pool_id> \
  --username testuser \
  --user-attributes Name=email,Value=testuser@example.com \
  --temporary-password "TempPass123!" \
  --profile <aws-profile-name> --region <aws-region>
```

Cognito requires a password reset before the user can sign in. To set a permanent password:

```
aws cognito-idp admin-set-user-password \
  --user-pool-id <cognito_user_pool_id> \
  --username testuser \
  --password "SecretPass@1" \
  --permanent \
  --profile <aws-profile-name> --region <aws-region>
```

Authenticate the user using Cognito and note down the value of `IdToken`, replace the value `cognito_user_pool_client_id` from the Terraform output:

```
aws cognito-idp initiate-auth \
  --client-id <cognito_user_pool_client_id> \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME="testuser",PASSWORD="SecretPass@1" \
  --profile <aws-profile-name> --region <aws-region>
```

The easier way to complete the above step is by using the following commands. This will store the `IdToken` value to the variable `ID_TOKEN`:

```
AUTH_RESPONSE=$(aws cognito-idp initiate-auth \
  --client-id <cognito_user_pool_client_id> \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME="testuser",PASSWORD="SecretPass@1" \
  --profile <aws-profile-name> --region <aws-region>)

ID_TOKEN=$(echo $AUTH_RESPONSE | jq -r '.AuthenticationResult.IdToken')
```


## Creating the VPC using the API

Execute the following command to create a VPC using the new API and store its information in DynamoDB, replace the value `api_invoke_url` from the Terraform output:

```
curl -X POST <api_invoke_url>/vpc \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $ID_TOKEN" \
     -d '{
           "cidr_block": "10.0.0.0/16",
           "subnet_count": 50
         }'
```

Execute the following command to fetch information about the VPC API from DynamoDB, replace the value `api_invoke_url` from the Terraform output and provide a value for `vpc_id`:

```
curl -H "Authorization: Bearer $ID_TOKEN" <api_invoke_url>/vpc/<vpc_id>
```


## Deleting the resources

Execute the following command and enter `yes` when prompted to delete all the infrastructure created by this repository:

```
terraform destroy
```

Please be aware that the VPC resources created using the API will need to be manually deleted.


### Improvements & future enhancements

This repository is a work in progress. Below are potential improvements and areas for enhancement:

- State management: Implement S3 + DynamoDB backend for Terraform to manage infrastructure state efficiently.
- Logging & Monitoring: Enhance logging to improve observability and debugging capabilities.
- Configuration flexibility: Replace hardcoded values with configurable variables for better maintainability.
- Rate limiting & throttling: Introduce rate limiting and API Gateway throttling to protect against excessive requests. Evaluate whether to split API Gateway into separate endpoints for VPC creation, retrieval and different rate limits for the two endpoints(and also to follow [SRP](https://en.wikipedia.org/wiki/Single-responsibility_principle)).
- IAM access control: Implement fine-grained IAM roles instead of full-access permissions for better security.
- Modularization: Refactor Terraform configurations and Lambda functions into reusable modules.
- Security enhancements: Integrate AWS WAF and AWS Shield to protect against attacks.
- Performance optimization: Optimize background processing for subnet creation by leveraging message queues (e.g., Amazon SQS, RabbitMQ, or Redis) to handle subnet provisioning asynchronously when the number of subnets exceeds API Gateway's execution limits.
- CI/CD integration: Set up CI/CD pipelines to automate testing and deployment of this repository.
- Architecture documentation: Provide a simple architecture diagram for better understanding.
