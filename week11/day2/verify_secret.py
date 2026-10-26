"""
Week 11 Day 2 — Secrets Manager verification.

Read-only validation against the local floci environment.
Uses dummy training credentials only.
"""

import json
import boto3

ENDPOINT = "http://localhost:4566"
REGION = "us-east-1"
SECRET_NAME = "cloudlab/week11/day2/demo-db"

EXPECTED_VERSION = "fe8144a8-fcdc-4538-a149-aed9114381b2"


def main():
    client = boto3.client(
        "secretsmanager",
        endpoint_url=ENDPOINT,
        region_name=REGION,
        aws_access_key_id="test",
        aws_secret_access_key="test",
    )

    response = client.get_secret_value(
        SecretId=SECRET_NAME
    )

    data = json.loads(response["SecretString"])

    assert data["username"] == "demo_user"
    assert data["password"] == "dummy-training-value-v2-not-real"
    assert response["VersionId"] == EXPECTED_VERSION
    assert "AWSCURRENT" in response["VersionStages"]

    print("PASS: Dummy secret retrieved successfully")
    print("PASS: Credential fields validated")
    print("PASS: Correct current version retrieved")
    print("PASS: AWSCURRENT staging label verified")
    print("PASS: No secret values printed")


if __name__ == "__main__":
    main()
