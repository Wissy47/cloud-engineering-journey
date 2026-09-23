# Week 4 Day 2 — Internet Gateway and Route Tables

## Objective

Understand how AWS routes traffic between subnets, the VPC, and the internet and Configure internet routing for a public subnet while keeping the private subnet isolated from direct internet access.

## Architecture

VPC:
10.40.0.0/16

Public Subnet:
10.40.1.0/24

Private Subnet:
10.40.2.0/24

## Components Created

- Internet Gateway
- Custom public route table
- Default route to Internet Gateway
- Public subnet route-table association
- Automatic public IPv4 assignment

## Important Routes

Public route table:

10.40.0.0/16 -> local
0.0.0.0/0 -> Internet Gateway

Private/main route table:

10.40.0.0/16 -> local


## Resources

- VPC: vpc-c1d0eaf8
- VPC CIDR: 10.40.0.0/16
- Public subnet: subnet-f8d5a80c
- Public subnet CIDR: 10.40.1.0/24
- Private subnet: subnet-9a4a8120
- Private subnet CIDR: 10.40.2.0/24
- Internet Gateway: igw-84c0dacb
- Public route table: rtb-a3a7467a
- Route table association: rtbassoc-14906cdd


## Key Concepts

- Every VPC receives a main route table automatically.
- A custom route table can be associated with a specific subnet.
- A subnet becomes public when it has a route to an Internet Gateway.
- 0.0.0.0/0 represents all IPv4 destinations not matched by a more specific route.
- Public IP assignment and internet routing are separate concepts.
- MapPublicIpOnLaunch was enabled for the public subnet.
- The private subnet was left without a direct Internet Gateway route.