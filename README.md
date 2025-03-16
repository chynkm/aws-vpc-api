# AWS VPC API

Creating an AWS VPC using serverless tools.


### Install Git Pre-commit hooks

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


### Terraform setup

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
