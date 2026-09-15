# Week 2 — Day 1: AWS VPC Fundamentals

## Objectives

- Understand AWS VPC architecture
- Understand IPv4 CIDR notation
- Identify the default VPC
- Inspect AWS subnets
- Inspect route tables
- Inspect the Internet Gateway
- Inspect security groups
- Understand the relationship between Regions, VPCs, AZs and subnets

## Architecture

VPC CIDR:

```text
VPC: 10.0.0.0/16

Public Subnet:
10.0.1.0/24

Private Subnet:
10.0.2.0/24


aws --version

aws sts get-caller-identity

aws configure get region

aws ec2 describe-vpcs \
  --query 'Vpcs[*].[VpcId,CidrBlock,IsDefault,State]' \
  --output table

aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$DEFAULT_VPC_ID" \
  --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]' \
  --output table

aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$DEFAULT_VPC_ID"

aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$DEFAULT_VPC_ID"

aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$DEFAULT_VPC_ID"