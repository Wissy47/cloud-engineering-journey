# Week 4 Day 4 — Public and Private Subnets with NAT

## Objective

Understand how resources in a private subnet can access the internet without being directly exposed to inbound internet traffic.

## VPC

* VPC ID: `vpc-c1d0eaf8`
* CIDR: `10.40.0.0/16`

## Public Subnet

* Subnet ID: `subnet-f8d5a80c`
* CIDR: `10.40.1.0/24`
* MapPublicIpOnLaunch: `True`

## Private Subnet

* Subnet ID: `subnet-9a4a8120`
* CIDR: `10.40.2.0/24`
* MapPublicIpOnLaunch: `False`

## Internet Gateway

* Internet Gateway ID: `igw-84c0dacb`

## Public Route Table

* Route Table ID: `rtb-a3a7467a`

Routes:

```text id="be0ybx"
10.40.0.0/16 -> local
0.0.0.0/0    -> igw-84c0dacb
```

## Private Route Table

* Route Table ID: `rtb-e287978c`
* Association ID: `rtbassoc-15a93fd9`

Routes:

```text id="f4r2az"
10.40.0.0/16 -> local
0.0.0.0/0    -> nat-23913eaf6d8356963
```

## NAT Gateway

* NAT Gateway ID: `nat-23913eaf6d8356963`
* State: `available`
* Subnet: `subnet-f8d5a80c`
* Elastic IP Allocation ID: `eipalloc-85a2cfe84cdc2a303`

## Traffic Flow

```text id="w1f66k"
Private EC2
   ↓
Private Subnet
   ↓
Private Route Table
   ↓
NAT Gateway
   ↓
Public Subnet
   ↓
Public Route Table
   ↓
Internet Gateway
   ↓
Internet
```

## Key Concepts

* Public subnets route internet-bound traffic directly to an Internet Gateway.
* Private subnets should not have a direct route to an Internet Gateway.
* A NAT Gateway provides outbound internet connectivity for private resources.
* A public NAT Gateway must be placed in a public subnet.
* The private subnet routes `0.0.0.0/0` to the NAT Gateway.
* The public subnet routes `0.0.0.0/0` to the Internet Gateway.
* Private instances can initiate outbound internet connections without being directly reachable from the internet.

## Troubleshooting Order

When a private instance cannot access the internet:

1. Confirm the instance is in the private subnet.
2. Confirm the private subnet is associated with the private route table.
3. Confirm the private route table has `0.0.0.0/0` pointing to the NAT Gateway.
4. Confirm the NAT Gateway is available.
5. Confirm the NAT Gateway is in the public subnet.
6. Confirm the public subnet routes `0.0.0.0/0` to the Internet Gateway.
7. Confirm the Internet Gateway is attached to the VPC.
8. Check NACL and Security Group rules.
