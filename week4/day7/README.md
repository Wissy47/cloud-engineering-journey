# Week 4 Day 7 — VPC Mini-Project

## Objective

Validate and document a multi-AZ Amazon VPC architecture with public and private subnets, routing, internet connectivity, NAT, security controls, DNS, and network troubleshooting.

## VPC

```text
VPC ID: vpc-c1d0eaf8
CIDR: 10.40.0.0/16
```

## Availability Zones

```text
us-east-1a
us-east-1b
```

## Subnet Architecture

### us-east-1a

Public subnet:

```text
subnet-f8d5a80c
10.40.1.0/24
MapPublicIpOnLaunch: True
```

Private subnet:

```text
subnet-9a4a8120
10.40.2.0/24
MapPublicIpOnLaunch: False
```

### us-east-1b

Public subnet:

```text
subnet-fc160cb6
10.40.3.0/24
MapPublicIpOnLaunch: True
```

Private subnet:

```text
subnet-9fb59c20
10.40.4.0/24
MapPublicIpOnLaunch: False
```

## Internet Gateway

```text
igw-84c0dacb
```

Attached to:

```text
vpc-c1d0eaf8
```

## NAT Gateway

```text
nat-23913eaf6d8356963
```

Located in:

```text
subnet-f8d5a80c
```

Elastic IP allocation:

```text
eipalloc-85a2cfe84cdc2a303
```

## Public Route Table

```text
rtb-a3a7467a
```

Associated with:

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

```text
rtb-e287978c
```

Associated with:

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

## Security Group

```text
sg-22fad3cc5698529e6
week4-web-sg
```

Inbound:

```text
TCP 80 from 0.0.0.0/0
```

Outbound:

```text
All traffic
```

## Public Network ACL

```text
acl-4df6f0c6e5ee0d486
```

Associated with:

```text
subnet-f8d5a80c
```

Inbound:

```text
100    ALLOW TCP 80
32767  DENY all
```

Outbound:

```text
100    ALLOW TCP 1024-65535
32767  DENY all
```

## DNS

The VPC was configured with DNS support and DNS hostnames enabled.

Important DNS troubleshooting commands:

```bash
cat /etc/resolv.conf
resolvectl status
getent hosts example.com
nslookup example.com
dig example.com
```

## Network Troubleshooting Workflow

When connectivity fails:

1. Verify the application is running.
2. Verify the application is listening on the correct port.
3. Verify the instance IP configuration.
4. Verify subnet placement.
5. Verify route-table association.
6. Verify the default route.
7. Verify the Internet Gateway or NAT Gateway.
8. Verify Network ACL rules.
9. Verify Security Group rules.
10. Verify DNS resolution.
11. Verify the operating system firewall.

Useful Linux commands:

```bash
ss -tulpn
curl -I http://127.0.0.1
ip addr
ip route
ip route get 8.8.8.8
ping 8.8.8.8
nc -zv <IP> <PORT>
```

## Architecture

```text
                         Internet
                            |
                           IGW
                            |
             +--------------+--------------+
             |                             |
        us-east-1a                    us-east-1b
             |                             |
      Public Subnet A               Public Subnet B
       10.40.1.0/24                  10.40.3.0/24
             |                             |
             +------ Public RT ------------+
                    0.0.0.0/0 -> IGW

                    NAT Gateway
                         |
             +-----------+-----------+
             |                       |
      Private Subnet A          Private Subnet B
       10.40.2.0/24             10.40.4.0/24
             |                       |
             +------ Private RT -----+
                    0.0.0.0/0 -> NAT
```

## Production Improvement

The current lab uses a single NAT Gateway in `us-east-1a`.

For stronger availability, a production design would normally use one NAT Gateway per Availability Zone:

```text
Private A -> NAT A
Private B -> NAT B
```

This avoids making resources in one AZ depend on NAT infrastructure in another AZ.

## Key Lessons

* A VPC spans Availability Zones within a Region.
* A subnet belongs to exactly one Availability Zone.
* Public/private behavior is determined primarily by routing, not names.
* Public subnets use an Internet Gateway.
* Private subnets use NAT for outbound internet access.
* Route tables determine where traffic goes.
* Security Groups are stateful and work at the resource/ENI layer.
* NACLs are stateless and work at the subnet layer.
* DNS failures should be diagnosed separately from routing failures.
* Multi-AZ design improves resilience.
* Network troubleshooting should be systematic rather than based on random configuration changes.
