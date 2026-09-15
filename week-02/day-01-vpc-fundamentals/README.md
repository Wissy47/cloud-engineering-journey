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

## Lab Observations

The local AWS environment contained a default VPC:

- VPC CIDR: `172.31.0.0/16`
- Region: `us-east-1`
- Three default subnets were present across separate Availability Zones.
- Each subnet had `MapPublicIpOnLaunch` enabled.
- The default route table contained:
  - `172.31.0.0/16 -> local`
  - `0.0.0.0/0 -> Internet Gateway`
- The Internet Gateway was attached to the default VPC.
- The VPC contained both the default security group and the existing `cloud-lab-sg`.

## Key Troubleshooting Model

For an internet-facing EC2 instance, verify:

1. The instance is in the correct subnet.
2. The subnet has a route to an Internet Gateway.
3. The instance has a public IPv4 address.
4. The Security Group allows the required traffic.
5. The application is listening on the expected port.