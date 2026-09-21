# Week 3 — Day 5: ENIs & IP Addressing

## Objectives

* Understand Elastic Network Interfaces
* Understand how EC2 connects to a VPC
* Understand primary ENIs
* Understand private IPv4 addresses
* Understand public IPv4 addresses
* Understand Elastic IP addresses
* Understand secondary private IPs conceptually
* Understand ENI lifecycle behavior
* Compare real AWS networking behavior with Floci

## What Is an ENI?

ENI stands for:

**Elastic Network Interface**

An ENI is a virtual network interface used by an EC2 instance.

A useful mental model is:

```text
EC2 instance
   ↓
ENI
   ↓
Subnet
   ↓
VPC
```

The ENI represents the network identity of the instance.

## Compute, Storage, and Networking

Week 3 separated three major EC2 components:

```text
EC2 = compute

EBS = storage

ENI = networking
```

This separation is important because cloud resources do not have to be treated as one single machine.

## ENI Information

The primary ENI inspected during the lab was:

```text
ENI:
eni-04e1e528cb5ead7d1

Private IP:
172.17.0.3

Subnet:
subnet-6cdbaae2

VPC:
vpc-a1b49c88

Status:
in-use

Security Group:
cloud-web-sg
```

The ENI was associated with the EC2 instance through its primary network interface.

## Floci Private IP Behavior

Floci returned:

```text
172.17.0.3
```

as the private IP.

This address comes from the local Docker-backed networking used by Floci.

In real AWS, the private IP would normally come from the subnet CIDR.

Example:

```text
Subnet:
10.0.1.0/24

Possible EC2 private IP:
10.0.1.25
```

Therefore, the Floci address should not be confused with normal AWS VPC addressing behavior.

## Security Groups and ENIs

The ENI showed the security group:

```text
cloud-web-sg
```

Security groups are associated with network interfaces.

This helps explain why security groups are considered instance/network-interface level firewalls rather than subnet-level controls.

## Private IP Address

A private IP is used for internal VPC communication.

Example:

```text
10.0.1.25
```

Private IP addresses are not directly internet routable.

They are used for communication such as:

```text
EC2 → EC2
EC2 → database
application → internal API
```

## Public IP Address

A public IPv4 address allows internet-facing communication when routing and security configuration also permit it.

An automatically assigned public IP is generally temporary.

Important lifecycle rule:

```text
Reboot
→ public IP normally stays the same

Stop / Start
→ auto-assigned public IP may change
```

## Elastic IP

An Elastic IP is a static public IPv4 address allocated to an AWS account.

The lab had:

```text
Elastic IP:
54.13.182.123

Allocation ID:
eipalloc-0c1c92df159bd81fd
```

Initially, it was not associated with any resource.

Conceptually:

```text
Allocate Elastic IP
→ reserve address

Associate Elastic IP
→ connect address to network identity
```

## Public IP vs Elastic IP

```text
Auto-assigned Public IP
→ temporary
→ may change after stop/start

Elastic IP
→ static
→ remains stable while allocated/associated
```

If a stable internet-facing IP is required, an Elastic IP is more appropriate than relying on an automatically assigned public IP.

## Elastic IP Association Test

Floci accepted the association operation and returned:

```text
Association ID:
eipassoc-4a318113cae6deb1b
```

However, subsequent metadata queries returned null values for:

```text
InstanceId
NetworkInterfaceId
PrivateIpAddress
```

This demonstrated a Floci emulation limitation.

In real AWS, the relationship is conceptually:

```text
Elastic IP
   ↓
ENI / private IP
   ↓
EC2 instance
```

## Secondary Private IPs

A real AWS ENI can have:

```text
Primary private IP
+
Secondary private IP addresses
```

Secondary private IPs can be useful for:

* Multiple service identities
* Application failover
* Moving an application endpoint
* Advanced networking designs

The real AWS command would look like:

```bash
aws ec2 assign-private-ip-addresses \
  --network-interface-id "$ENI_ID" \
  --secondary-private-ip-address-count 1
```

Floci returned:

```text
UnsupportedOperation
```

so secondary private IPs were studied conceptually.

## Secondary ENIs

In real AWS, an EC2 instance can have additional ENIs depending on the instance type.

Conceptually:

```text
EC2
├── ENI 0
│   └── primary interface
│
└── ENI 1
    └── secondary interface
```

A secondary ENI can potentially be detached and attached to another compatible EC2 instance.

This can be useful for failover designs.

Floci did not support standalone ENI creation in the current environment, so this portion was conceptual.

## Primary ENI Lifecycle

The primary ENI remains associated with the EC2 instance through normal stop/start operations.

The lab tested stop/start behavior.

The private IP remained unchanged.

This reinforced the real AWS rule:

```text
Stop / Start

Primary ENI  → remains
Private IP   → remains
Public IP    → may change
Elastic IP   → remains if associated
```

## Reboot vs Stop/Start

A reboot and a stop/start are different.

### Reboot

```text
Instance stays allocated
Same ENI
Same private IP
Same auto-assigned public IP
```

### Stop / Start

```text
Instance stops
Instance starts again

Primary ENI stays
Private IP stays
Auto-assigned public IP may change
```

This distinction is important for troubleshooting systems that rely on a public IP.

## Key Concepts Learned

* ENI means Elastic Network Interface
* ENIs provide network identity to EC2
* ENIs belong to subnets
* Subnets belong to VPCs
* Security groups are associated with ENIs
* Private IPs are used inside the VPC
* Public IPs provide internet-facing addressing
* Auto-assigned public IPs may change after stop/start
* Reboots normally preserve the public IP
* Elastic IPs provide stable public IPv4 addressing
* Primary ENIs stay attached through stop/start
* Primary private IPs normally remain unchanged
* Secondary private IPs and secondary ENIs enable more advanced network designs
* Floci does not reproduce every AWS ENI operation or networking behavior
