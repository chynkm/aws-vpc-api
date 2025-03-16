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


## Terraform setup

The repo can be deployed using Terraform.
Install terraform on your local machine using [tfenv](https://github.com/tfutils/tfenv).


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

Create a new user in Cognito using the following commands, replace the value `cognito_user_pool_id` from the Terraform output:

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

Authenticate the user using Cognito and note down the value of `IdToken`:

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

Execute the following command to create a VPC using the new API and store its information in DynamoDB:

```
curl -X POST <api_invoke_url>/vpc \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $ID_TOKEN" \
     -d '{
           "cidr_block": "10.0.0.0/16",
           "subnet_count": 50
         }'
```

Execute the following command to fetch information about the VPC API from DynamoDB:

```
curl -H "Authorization: Bearer $ID_TOKEN" <api_invoke_url>/vpc/<vpc_id>
```
