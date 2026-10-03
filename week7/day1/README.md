# Week 7 Day 1 — Amazon S3 Fundamentals

## Objective

Learn Amazon S3 object storage and manage buckets and objects using the AWS CLI.

## Concepts Learned

- Object storage
- S3 buckets
- Objects
- Object keys
- S3 vs S3API
- Uploading objects
- Downloading objects
- Recursive uploads
- S3 sync
- Object metadata
- Public access protection

## Commands Used

```bash
aws s3 ls
aws s3api list-buckets
aws s3api create-bucket
aws s3 cp
aws s3 sync
aws s3 rm
aws s3api put-object
aws s3api head-object
aws s3api list-objects-v2
```

## Key Takeaways
- S3 is object storage.
- Buckets contain objects.
- Object keys identify objects.
- aws s3 provides high-level file operations.
- aws s3api exposes lower-level S3 API operations.
- S3 is different from EBS and EFS.