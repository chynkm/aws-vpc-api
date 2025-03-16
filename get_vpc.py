import json
import boto3
import decimal
import os

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["DYNAMODB_TABLE"])


# Utility function to convert Decimal values
# DynamoDB stores numeric values as decimal.Decimal
def convert_decimals(obj):
    if isinstance(obj, list):
        return [convert_decimals(i) for i in obj]
    elif isinstance(obj, dict):
        return {k: convert_decimals(v) for k, v in obj.items()}
    elif isinstance(obj, decimal.Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    return obj


def validate_path_parameters(event):
    if "pathParameters" not in event or not event["pathParameters"]:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Missing VPC ID in request"}),
        }, None

    vpc_id = event["pathParameters"].get("vpc_id", "").strip()
    if not vpc_id:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "VPC ID cannot be empty"}),
        }, None

    return None, vpc_id


def lambda_handler(event, context):
    try:
        error_response, vpc_id = validate_path_parameters(event)
        if error_response:
            return error_response

        response = table.get_item(Key={"vpc_id": vpc_id})

        if "Item" not in response:
            return {
                "statusCode": 404,
                "body": json.dumps({"error": f"VPC with ID {vpc_id} not found"}),
            }

        vpc_data = convert_decimals(response["Item"])

        return {"statusCode": 200, "body": json.dumps(vpc_data)}

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": f"Internal Server Error: {str(e)}"}),
        }
