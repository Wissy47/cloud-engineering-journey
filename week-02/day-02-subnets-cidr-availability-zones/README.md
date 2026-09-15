# Week 2 — Day 2: Subnets, CIDR Planning & Availability Zones

## Objectives

- Understand subnet CIDR planning
- Prevent overlapping subnet ranges
- Understand the relationship between subnets and Availability Zones
- Create a custom VPC
- Create public and private subnets
- Understand main vs explicitly associated route tables
- Understand what makes a subnet public

## Custom VPC

- VPC CIDR: `10.0.0.0/16`
- VPC ID: `vpc-9d40ccf5`

## Subnets

### Public Subnet

- Subnet ID: `subnet-b7a9f11b`
- CIDR: `10.0.1.0/24`
- Availability Zone: `us-east-1a`
- MapPublicIpOnLaunch: `False`

### Private Subnet

- Subnet ID: `subnet-ea5a5e5d`
- CIDR: `10.0.2.0/24`
- Availability Zone: `us-east-1a`
- MapPublicIpOnLaunch: `False`

## CIDR Planning

`10.0.1.0/24` covers:

`10.0.1.0 - 10.0.1.255`

`10.0.2.0/24` covers:

`10.0.2.0 - 10.0.2.255`

The two subnet ranges do not overlap.

A subnet such as `10.0.1.128/25` could not be added because it falls inside the existing `10.0.1.0/24` range.

## Availability Zones

Both current subnets were created in:

`us-east-1a`

This is valid but does not provide Availability Zone redundancy.

A future multi-AZ design could use additional non-overlapping subnets in `us-east-1b`.

## Internet Gateway

Internet Gateway:

`igw-82949a9e`

The Internet Gateway is attached to the custom VPC.

## Route Tables

### Public Route Table

Route table:

`rtb-b515d0c4`

Routes:

- `10.0.0.0/16 → local`
- `0.0.0.0/0 → igw-82949a9e`

Explicitly associated with:

`subnet-b7a9f11b`

### Main Route Table

Route table:

`rtb-aa530eaf0ac1b2768`

Route:

- `10.0.0.0/16 → local`

The private subnet has no explicit route-table association, so it inherits the VPC main route table.

## Key Concepts Learned

- VPCs are regional.
- Subnets belong to one Availability Zone.
- Subnet CIDR ranges cannot overlap.
- A public subnet is defined by routing to an Internet Gateway.
- A public IP alone does not make a subnet public.
- A subnet without an explicit route-table association uses the VPC main route table.
- `MapPublicIpOnLaunch` controls automatic public IP assignment and is separate from whether the subnet is public by routing.