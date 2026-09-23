# Week 4 Day 2 — Internet Gateway and Route Tables

## Objective

Understand how AWS routes traffic between subnets, the VPC, and the internet.

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

## Key Concepts

- Every VPC has a main route table.
- Custom route tables can be created for individual subnets.
- A public subnet needs a route to an Internet Gateway.
- 0.0.0.0/0 represents destinations not matched by a more specific IPv4 route.
- Public IP assignment and internet routing are separate concepts.
- Private subnets normally do not have a direct route to an Internet Gateway.