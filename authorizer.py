import json
import os
import jwt
import boto3
import requests

COGNITO_USER_POOL_ID = os.environ["COGNITO_USER_POOL_ID"]
REGION = os.environ["MY_AWS_REGION"]


def get_cognito_public_keys():
    """Fetch Cognito's public signing keys."""
    url = f"https://cognito-idp.{REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}/.well-known/jwks.json"
    response = requests.get(url)
    return {key["kid"]: key for key in response.json()["keys"]}


COGNITO_KEYS = get_cognito_public_keys()


def lambda_handler(event, context):
    try:
        token = event["authorizationToken"].split(" ")[1]
        headers = jwt.get_unverified_header(token)
        key = COGNITO_KEYS.get(headers["kid"])

        if not key:
            raise Exception("Invalid token key ID")

        public_key = jwt.algorithms.RSAAlgorithm.from_jwk(json.dumps(key))
        decoded_token = jwt.decode(
            token,
            public_key,
            algorithms=["RS256"],
            audience=os.environ["COGNITO_CLIENT_ID"],
        )

        return {
            "principalId": decoded_token["sub"],
            "policyDocument": {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Action": "execute-api:Invoke",
                        "Effect": "Allow",
                        "Resource": event["methodArn"],
                    }
                ],
            },
            "context": {
                "username": decoded_token.get("username", "unknown_user"),
                "email": decoded_token.get("email", "unknown_email"),
            },
        }

    except Exception as e:
        return {
            "principalId": "unauthorized",
            "policyDocument": {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Action": "execute-api:Invoke",
                        "Effect": "Deny",
                        "Resource": event["methodArn"],
                    }
                ],
            },
            "context": {"error": str(e)},
        }
