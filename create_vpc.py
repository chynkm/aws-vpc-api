import json
import boto3
import time
import ipaddress
import os

ec2 = boto3.client("ec2")
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["DYNAMODB_TABLE"])

# Subnet mask values which support in AWS VPC
MIN_CIDR_PREFIX = 16
MAX_CIDR_PREFIX = 28


def parse_event_body(event):
    """Parse and return the JSON body from the API Gateway event."""
    body = event.get("body")
    if isinstance(body, str):
        return json.loads(body)
    return body


def validate_cidr_block(cidr_block):
    """Validate the given CIDR block format and size."""
    try:
        network = ipaddress.ip_network(cidr_block, strict=False)
    except ValueError:
        return False, "Invalid CIDR block format"

    if network.prefixlen < MIN_CIDR_PREFIX:
        return (
            False,
            f"AWS does not support CIDR blocks larger than /{MIN_CIDR_PREFIX}. You provided: {cidr_block}",
        )

    if network.prefixlen > MAX_CIDR_PREFIX:
        return (
            False,
            f"AWS allows CIDR blocks between /{MIN_CIDR_PREFIX} and /{MAX_CIDR_PREFIX}. You provided: {cidr_block}",
        )

    return True, None


def max_possible_subnets(vpc_cidr, subnet_prefix):
    """Calculate the maximum number of subnets that can fit in the given CIDR block."""
    vpc_network = ipaddress.ip_network(vpc_cidr, strict=False)
    subnet_network = ipaddress.ip_network(f"0.0.0.0/{subnet_prefix}", strict=False)
    return vpc_network.num_addresses // subnet_network.num_addresses


def validate_subnet_count(cidr_block, subnet_count, subnet_prefix):
    """Ensure the subnet count is within the allowable range."""
    max_subnets = max_possible_subnets(cidr_block, subnet_prefix)
    if subnet_count > max_subnets:
        return (
            False,
            f"Maximum possible subnets for {cidr_block} with /{subnet_prefix} is {max_subnets}",
        )
    return True, None


def create_vpc(cidr_block):
    """Create a VPC and return its ID."""
    vpc_response = ec2.create_vpc(CidrBlock=cidr_block)
    return vpc_response["Vpc"]["VpcId"]


def generate_subnets(vpc_cidr, subnet_count, subnet_prefix):
    """Manually generate subnet CIDR blocks starting from the exact provided CIDR."""
    subnets = []

    start_ip = ipaddress.IPv4Address(vpc_cidr.split("/")[0])
    subnet_size = 2 ** (32 - subnet_prefix)

    for _ in range(subnet_count):
        subnet = ipaddress.ip_network(f"{start_ip}/{subnet_prefix}", strict=False)
        subnets.append(str(subnet))
        start_ip += subnet_size

    return subnets


def create_subnets(vpc_id, subnets):
    """Create subnets within the given VPC."""
    subnet_ids = []
    for subnet_cidr in subnets:
        subnet_response = ec2.create_subnet(VpcId=vpc_id, CidrBlock=subnet_cidr)
        subnet_ids.append(subnet_response["Subnet"]["SubnetId"])
    return subnet_ids


def store_vpc_in_dynamodb(vpc_id, cidr_block, subnet_prefix, subnets):
    """Store VPC details in DynamoDB."""
    table.put_item(
        Item={
            "vpc_id": vpc_id,
            "cidr_block": cidr_block,
            "subnet_prefix": subnet_prefix,
            "subnets": subnets,
            "created_at": int(time.time()),
        }
    )


def lambda_handler(event, context):
    try:
        body = parse_event_body(event)
        if not body:
            return {
                "statusCode": 400,
                "body": json.dumps(
                    {"success": False, "message": "Invalid request body"}
                ),
            }

        cidr_block = body.get("cidr_block", "10.0.0.0/16")
        subnet_count = int(body.get("subnet_count", 2))
        # default to configure 256 IP address for each subnet
        subnet_prefix = int(body.get("subnet_prefix", 24))

        is_valid, error_message = validate_cidr_block(cidr_block)
        if not is_valid:
            return {
                "statusCode": 400,
                "body": json.dumps({"success": False, "message": error_message}),
            }

        is_valid, error_message = validate_subnet_count(
            cidr_block, subnet_count, subnet_prefix
        )
        if not is_valid:
            return {
                "statusCode": 400,
                "body": json.dumps({"success": False, "message": error_message}),
            }

        vpc_id = create_vpc(cidr_block)
        subnet_cidrs = generate_subnets(cidr_block, subnet_count, subnet_prefix)
        subnet_ids = create_subnets(vpc_id, subnet_cidrs)

        store_vpc_in_dynamodb(vpc_id, cidr_block, subnet_prefix, subnet_ids)

        return {
            "statusCode": 201,
            "body": json.dumps(
                {
                    "success": True,
                    "message": "VPC created successfully",
                    "data": {"vpc_id": vpc_id, "subnets": subnet_ids},
                }
            ),
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps(
                {"success": False, "message": "Internal Server Error", "error": str(e)}
            ),
        }
