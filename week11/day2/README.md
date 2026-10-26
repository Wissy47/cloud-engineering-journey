# Week 11 — Day 2: KMS, Encryption & Secrets Manager

## Project Overview

Implemented a local AWS-compatible encryption and secret-management
lab using floci, AWS CLI, Python, and Boto3.

Created a symmetric KMS key, performed encryption and decryption,
configured a KMS alias, inspected key permissions, created a dummy
database secret, and verified secret versioning and retrieval.

All operations were performed against the local floci endpoint.

## Environment

| Component | Configuration |
|---|---|
| Computer | Apple Silicon M1 Mac |
| AWS emulator | floci |
| Endpoint | http://localhost:4566 |
| Region | us-east-1 |
| Python | 3.13.0 |
| Boto3 | 1.43.118 |
| Virtual environment | week11/day2/.venv |

## Architecture

```text
Python Application
       |
       | GetSecretValue
       v
AWS Secrets Manager (floci)
       |
       | Uses customer-managed KMS key
       v
AWS KMS (floci)
       |
       v
Protected secret storage

The application retrieves the current secret version through
Secrets Manager. KMS is used to protect secret values.

The local emulator demonstrates API workflows but does not
establish production AWS security guarantees.
1. Encryption Fundamentals
Encryption at rest protects stored information, such as S3
objects, EBS volumes, database storage, and backups.

Encryption in transit protects information moving between
systems, typically through TLS.

These protections complement IAM access controls.
2. KMS Key Creation
Command:
aws --endpoint-url=http://localhost:4566 \
  --region us-east-1 \
  kms create-key \
  --description "Week11-Day2-CloudLab-Encryption-Key" \
  --key-usage ENCRYPT_DECRYPT \
  --key-spec SYMMETRIC_DEFAULT \
  --output json


Observed key metadata:
- Key ID: 6cc74b59-d5de-4ef7-8f14-b228f730eaec
- Key state: Enabled
- Usage: ENCRYPT_DECRYPT
- Specification: SYMMETRIC_DEFAULT
- Key manager: CUSTOMER
- Origin: AWS_KMS
The key was subsequently verified using describe-key and
list-keys. Only one KMS key was returned in the inventory.

The same key was reused throughout the exercises.
3. Encryption and Decryption
Created a 35-byte dummy plaintext file.

Encryption:
aws --endpoint-url=http://localhost:4566 \
  --region us-east-1 \
  kms encrypt \
  --key-id "6cc74b59-d5de-4ef7-8f14-b228f730eaec" \
  --plaintext fileb://week11/day2/plaintext.txt \
  --query CiphertextBlob \
  --output text \
  | base64 --decode > week11/day2/ciphertext.bin


Decryption:
aws --endpoint-url=http://localhost:4566 \
  --region us-east-1 \
  kms decrypt \
  --ciphertext-blob fileb://week11/day2/ciphertext.bin \
  --key-id "6cc74b59-d5de-4ef7-8f14-b228f730eaec" \
  --query Plaintext \
  --output text \
  | base64 --decode > week11/day2/decrypted.txt


Verification:
cmp week11/day2/plaintext.txt \
    week11/day2/decrypted.txt \
  && echo "PASS: Decrypted data matches original plaintext"


Observed:
- Original plaintext: 35 bytes
- Ciphertext: 144 bytes
- Decrypted plaintext: 35 bytes
- Byte-for-byte comparison: PASS
The observed ciphertext format was specific to floci.

Generated plaintext and ciphertext files are excluded from Git.
4. KMS Key Policy Review
Inspected the default key policy:
aws --endpoint-url=http://localhost:4566 \
  --region us-east-1 \
  kms get-key-policy \
  --key-id "6cc74b59-d5de-4ef7-8f14-b228f730eaec" \
  --policy-name default \
  --query Policy \
  --output text


The policy contained an account-principal statement:
- Principal: arn:aws:iam::000000000000:root
- Action: kms:*
- Resource: *
In a KMS key policy, this statement enables IAM policy
delegation at the account level. It does not automatically
grant every IAM identity unrestricted access.

No key policy changes were made.
5. KMS Alias
Created:

alias/cloudlab-week11-day2

Command:
aws --endpoint-url=http://localhost:4566 \
  --region us-east-1 \
  kms create-alias \
  --alias-name alias/cloudlab-week11-day2 \
  --target-key-id \
  "6cc74b59-d5de-4ef7-8f14-b228f730eaec"


Verified that the alias referenced the existing key.

The key inventory still contained one key.

Aliases provide human-readable references without
creating additional cryptographic key material.
6. Secrets Manager
Initially verified that the Secrets Manager inventory
was empty.

Created a dedicated dummy secret:

cloudlab/week11/day2/demo-db

Creation used the existing customer-managed KMS key.

Verified secret ARN:

arn:aws:secretsmanager:us-east-1:000000000000:secret:cloudlab/week11/day2/demo-db-RGCOAY

The secret contains harmless demonstration credentials,
not an actual database password.

DescribeSecret confirmed:
- Secret name and ARN
- KMS key association
- Initial version ID
- AWSCURRENT staging label
Secret values were not printed during metadata inspection.
7. Secret Versioning
Initial version:

8040eeaf-79c6-4330-8589-c31e841ad590

Updated version:

fe8144a8-fcdc-4538-a149-aed9114381b2

Created the updated version using PutSecretValue.

Verified staging labels:
Version	Staging label
Initial version	AWSPREVIOUS
Updated version	AWSCURRENT

ListSecretVersionIds and DescribeSecret confirmed the
expected version transition.

The version update did not change any actual PostgreSQL
database password.
8. Boto3 Verification
Created an isolated Python virtual environment and installed
Boto3 version 1.43.118.

Dependency manifest:

requirements.txt

Reproducible script:

verify_secret.py

Run:
source week11/day2/.venv/bin/activate
python week11/day2/verify_secret.py


Verified results:
PASS: Dummy secret retrieved successfully
PASS: Credential fields validated
PASS: Correct current version retrieved
PASS: AWSCURRENT staging label verified
PASS: No secret values printed


The script checks expected dummy values in memory without
printing them.

It is a local training verification script. It uses test
credentials and a fixed version ID, so it should not be
treated as a production-ready secret-retrieval client.
9. Troubleshooting
Missing Boto3 dependency
Initial error:
ModuleNotFoundError: No module named 'boto3'


Investigation identified:
- Python 3.13.0
- No active virtual environment
- Boto3 not installed in the selected interpreter
Resolution:
python3 -m venv week11/day2/.venv
source week11/day2/.venv/bin/activate
python -m pip install boto3


Verified Boto3 version 1.43.118 and reran the retrieval
exercise successfully.
Git Exclusions
Created a Day 2-specific .gitignore excluding:
- .venv/
- plaintext.txt
- decrypted.txt
- ciphertext.bin
- Python cache files
- Local .env files
All generated artifacts were verified as ignored.
10. Security Lessons
1. Encryption at rest and encryption in transit protect
   different stages of the data lifecycle.
2. Encryption and IAM access controls complement each other.
3. KMS keys and data keys have different responsibilities.
4. KMS key policies control access to cryptographic operations.
5. Applications should receive only necessary KMS permissions.
6. Base64 encoding is not encryption.
7. Secrets Manager protects and versions application secrets.
8. AWSCURRENT avoids hardcoded secret-version references.
9. Secret rotation must be coordinated with the actual system
   that uses the credentials.
10. Application logs should never expose real secret values.
11. Virtual environments isolate Python dependencies.
12. Generated sensitive files should not be committed to Git.
11. Limitations
This lab used the local floci AWS-compatible emulator.

Successful API calls do not prove that floci reproduces all
AWS IAM enforcement, KMS cryptographic guarantees, or
Secrets Manager rotation behavior.

Actual PostgreSQL credential rotation was not performed.

No production credentials were used.
12. Final Outcome
Successfully demonstrated:
- KMS key creation and inspection
- Symmetric encryption and decryption
- KMS alias creation
- KMS key-policy inspection
- Secrets Manager secret creation
- Secret metadata inspection
- Secret version updates
- AWSCURRENT and AWSPREVIOUS verification
- Python Boto3 secret retrieval
- Safe handling of generated lab files
Previous lab infrastructure and IAM policies were preserved.
Evidence
- Boto3 verification script
- Boto3 dependency manifest
- Git exclusions
- Verified AWS CLI and Python terminal results
References
- https://docs.aws.amazon.com/kms/
- https://docs.aws.amazon.com/secretsmanager/
- https://boto3.amazonaws.com/v1/documentation/api/latest/
