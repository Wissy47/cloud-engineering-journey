# Week 2 — Day 6: NAT Gateway, Elastic IPs & Private Internet Access

## Objectives

- Understand Network Address Translation
- Understand why private instances need NAT for outbound internet access
- Understand Elastic IPs
- Place a NAT Gateway in a public subnet
- Route private subnet internet traffic through NAT
- Understand the difference between IGW and NAT Gateway
- Troubleshoot private outbound connectivity

## Existing Architecture

VPC:

`10.0.0.0/16`

Public subnet:

`10.0.1.0/24`

Private subnet:

`10.0.2.0/24`

Internet Gateway:

`igw-82949a9e`

Public route table:

`rtb-b515d0c4`

Main/private route table:

`rtb-aa530eaf0ac1b2768`

## Elastic IP

Elastic IP allocation ID:

`eipalloc-e29556f106deebf5b`

An Elastic IP provides a stable public IPv4 identity for resources such as a public NAT Gateway.

## NAT Gateway

NAT Gateway:

`nat-226e6e0aee6a79548`

State:

`available`

Connectivity type:

`public`

Subnet:

`subnet-b7a9f11b`

The NAT Gateway was placed inside the public subnet.

## Why the NAT Gateway Is Public

The NAT Gateway must be able to reach the Internet Gateway.

Therefore it resides in a public subnet whose route table contains:

`0.0.0.0/0 -> Internet Gateway`

## Private Route Table

The private/main route table now contains:

- `10.0.0.0/16 -> local`
- `0.0.0.0/0 -> NAT Gateway`

This allows private resources to initiate outbound internet traffic without routing directly to the Internet Gateway.

## Public Route Table

The public route table contains:

- `10.0.0.0/16 -> local`
- `0.0.0.0/0 -> Internet Gateway`

## Packet Flow

Private EC2
↓
Private route table
↓
NAT Gateway
↓
Public subnet
↓
Internet Gateway
↓
Internet

## Internet Gateway vs NAT Gateway

### Internet Gateway

Used by public subnets for direct internet routing.

### NAT Gateway

Used by private subnet resources for outbound internet access.

The private subnet still does not have a direct route to the Internet Gateway.

## Key Security Property

Private resources can initiate outbound internet connections.

The internet cannot use the NAT Gateway as a general inbound path to directly initiate connections to those private instances.

## Troubleshooting Checklist

1. Verify the private instance subnet.
2. Verify the subnet's route table.
3. Confirm `0.0.0.0/0 -> NAT Gateway`.
4. Confirm the NAT Gateway is available.
5. Confirm the NAT Gateway is in the public subnet.
6. Confirm the public subnet routes to the Internet Gateway.
7. Confirm the Internet Gateway is attached to the VPC.
8. Confirm the NAT Gateway has an Elastic IP.
9. Check Security Groups and Network ACLs.
10. Check DNS when hostname resolution is involved.

## Key Concepts Learned

- NAT stands for Network Address Translation.
- EIP stands for Elastic IP.
- NAT Gateway belongs in a public subnet.
- A private subnet routes internet-bound traffic to NAT, not directly to the IGW.
- Public subnet: `0.0.0.0/0 -> IGW`.
- Private subnet with outbound internet: `0.0.0.0/0 -> NAT Gateway`.
- NAT enables outbound access without turning the private subnet into a public subnet.