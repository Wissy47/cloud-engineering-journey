# Week 7 Day 2 — S3 Versioning, Lifecycle & Security

## Objective

Understand S3 data protection and lifecycle management using floci.

## Environment

- AWS CLI
- floci
- Endpoint: http://localhost:4566
- Region: us-east-1

## Concepts Learned

- S3 versioning
- Version IDs
- Delete markers
- Object recovery
- Lifecycle policies
- Noncurrent object versions
- Server-side encryption
- Bucket policies
- ACLs

## Important Commands

Include:
- put-bucket-versioning
- get-bucket-versioning
- list-object-versions
- get-object --version-id
- put-bucket-lifecycle-configuration
- get-bucket-lifecycle-configuration
- put-bucket-encryption
- get-bucket-encryption

## Hands-On Lab

Document the config.txt versioning test.

## Recovery Exercise

Document the database.conf recovery exercise.

## Troubleshooting

Record any floci-specific errors encountered.

## Key Takeaways

- Versioning preserves historical object versions.
- A normal delete on a versioned object can create a delete marker.
- Previous versions can be retrieved using VersionId.
- Lifecycle policies automate object management.
- Encryption protects stored data.
- Bucket policies control access at the resource level.
