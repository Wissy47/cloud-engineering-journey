# Week 4 Day 1 — VPCs, CIDR and Subnets

## Objective

Understand Amazon VPC networking, CIDR ranges, Availability Zones,
and subnet design.

## Architecture

VPC: 10.40.0.0/16

Public subnet: 10.40.1.0/24
Private subnet: 10.40.2.0/24

## Commands Practiced

aws ec2 describe-vpcs
aws ec2 describe-subnets
aws ec2 describe-availability-zones
aws ec2 create-vpc
aws ec2 create-subnet
aws ec2 create-tags

## Key Concepts

- A VPC is a logically isolated network in AWS.
- A VPC spans Availability Zones in a Region.
- A subnet belongs to one Availability Zone.
- A subnet CIDR must fit inside its VPC CIDR.
- Naming a subnet "public" does not make it public.
- Routing determines whether a subnet is public or private.

## Lab Result

Created a Week 4 VPC using 10.40.0.0/16 and divided it into
two /24 subnets for later public/private networking labs.

## Important Observation

The subnet named `week4-public-subnet` was not yet truly public.

The VPC main route table only contained:

10.40.0.0/16 -> local

There was no default route to an Internet Gateway.

Also, `MapPublicIpOnLaunch` was disabled on both subnets.

This demonstrated that a subnet's name does not determine whether it is public.
Routing determines its network reachability.