# Week 2 — Day 3: Internet Gateways & Route Tables

## Objectives

- Understand AWS route-table behavior
- Understand main vs custom route tables
- Understand explicit subnet associations
- Understand longest-prefix match
- Understand the default route
- Troubleshoot missing internet routes

## Existing Lab Architecture

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

Main route table:

`rtb-aa530eaf0ac1b2768`

## Longest-Prefix Match

AWS selects the most specific matching route.

Example:

- `10.0.2.0/24`
- `10.0.0.0/16`
- `0.0.0.0/0`

Traffic destined for `10.0.2.50` uses `10.0.2.0/24` because `/24` is more specific than `/16` or `/0`.

Rule:

Longer prefix = smaller address range = more specific route.

## Route Table Associations

The public subnet is explicitly associated with:

`rtb-b515d0c4`

The private subnet has no explicit route-table association, so it inherits the VPC main route table:

`rtb-aa530eaf0ac1b2768`

An explicit subnet association takes precedence over the main route table.

## Association Test

The private subnet was temporarily associated with the public route table.

Both subnets then used the route table containing:

- `10.0.0.0/16 -> local`
- `0.0.0.0/0 -> Internet Gateway`

This made the former private subnet public by routing.

The explicit association was then removed, causing the subnet to fall back to the VPC main route table.

## Routing Failure Test

The public route:

`0.0.0.0/0 -> igw-82949a9e`

was intentionally removed.

The public route table then contained only:

`10.0.0.0/16 -> local`

This demonstrated that attaching an Internet Gateway to a VPC is not sufficient by itself.

The subnet also needs a route directing internet-bound traffic to the Internet Gateway.

The default route was then restored.

## Key Concepts Learned

- Route tables determine where traffic goes.
- `0.0.0.0/0` is the default IPv4 route.
- AWS uses longest-prefix matching.
- Explicit subnet route-table associations override main route-table inheritance.
- Subnets without explicit associations inherit the VPC main route table.
- An attached Internet Gateway does not automatically make a subnet public.
- A public subnet requires a route to an Internet Gateway.

## Troubleshooting Checklist

When a public instance cannot communicate with the internet:

1. Verify the subnet.
2. Verify the subnet's route-table association.
3. Check for `0.0.0.0/0`.
4. Verify the route points to the correct Internet Gateway.
5. Verify the Internet Gateway is attached to the correct VPC.
6. Check public IP assignment.
7. Check Security Groups.
8. Check Network ACLs.
9. Verify the service is listening.