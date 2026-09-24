# Week 4 Day 6 — Multi-AZ VPC Architecture

## Objective

Design a VPC across multiple Availability Zones to improve resilience and understand how public and private subnet routing works across AZs.

## VPC

* VPC ID: `vpc-c1d0eaf8`
* CIDR: `10.40.0.0/16`

## Availability Zones

The VPC uses:

* `us-east-1a`
* `us-east-1b`

## Subnet Layout

### us-east-1a

Public subnet:

```text
Subnet ID: subnet-f8d5a80c
CIDR: 10.40.1.0/24
MapPublicIpOnLaunch: True
```

Private subnet:

```text
Subnet ID: subnet-9a4a8120
CIDR: 10.40.2.0/24
MapPublicIpOnLaunch: False
```

### us-east-1b

Public subnet:

```text
Subnet ID: subnet-fc160cb6
CIDR: 10.40.3.0/24
MapPublicIpOnLaunch: True
```

Private subnet:

```text
Subnet ID: subnet-9fb59c20
CIDR: 10.40.4.0/24
MapPublicIpOnLaunch: False
```

## Public Route Table

Route table:

```text
rtb-a3a7467a
```

Associated subnets:

```text
subnet-f8d5a80c
subnet-fc160cb6
```

Routes:

```text
10.40.0.0/16 -> local
0.0.0.0/0    -> igw-84c0dacb
```

## Private Route Table

Route table:

```text
rtb-e287978c
```

Associated subnets:

```text
subnet-9a4a8120
subnet-9fb59c20
```

Routes:

```text
10.40.0.0/16 -> local
0.0.0.0/0    -> nat-23913eaf6d8356963
```

## Main Route Table

```text
rtb-895560b3e7e40b113
```

Route:

```text
10.40.0.0/16 -> local
```

All four lab subnets now use explicit custom route-table associations.

## Architecture

```text
                     Internet
                        │
                       IGW
                        │
         ┌──────────────┴──────────────┐
         │                             │
    us-east-1a                    us-east-1b
         │                             │
 Public Subnet A                Public Subnet B
 10.40.1.0/24                   10.40.3.0/24
         │                             │
         └──── Public Route Table ─────┘
              0.0.0.0/0 → IGW

 Private Subnet A               Private Subnet B
 10.40.2.0/24                   10.40.4.0/24
         │                             │
         └──── Private Route Table ────┘
              0.0.0.0/0 → NAT
```

## Key Concepts

* A VPC spans Availability Zones within a Region.
* A subnet exists in exactly one Availability Zone.
* Spreading resources across multiple AZs improves resilience.
* Public subnets route internet-bound traffic to an Internet Gateway.
* Private subnets route internet-bound traffic through NAT.
* Multiple subnets can share one route table.
* Explicit route-table associations override use of the VPC main route table.
* Production multi-AZ designs commonly avoid making one AZ depend on another AZ's NAT Gateway.

## Production Improvement

The current lab uses one NAT Gateway:

```text
nat-23913eaf6d8356963
```

located in the public subnet in `us-east-1a`.

A more resilient production design would use:

```text
Private A -> NAT A in us-east-1a
Private B -> NAT B in us-east-1b
```

with separate private route tables per Availability Zone.

## Troubleshooting Multi-AZ Networking

If one AZ works but another does not:

1. Verify the subnet Availability Zone.
2. Verify the CIDR block.
3. Check the route-table association.
4. Check the default route.
5. Check NAT or Internet Gateway path.
6. Verify NACL association and rules.
7. Verify Security Group rules.
8. Verify the application is listening.