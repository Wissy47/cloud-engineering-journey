# Day 4 — EC2, Security Groups & SSH

## Objective

Learn how to launch and manage an EC2 instance, configure network access with Security Groups, connect securely with SSH, and troubleshoot connectivity problems layer by layer.

## Topics Covered

* EC2 fundamentals
* AMIs
* Instance types
* ARM64 vs x86 architecture
* VPCs and subnets
* Security Groups
* Key pairs
* SSH
* Public and private IP addresses
* EC2 instance lifecycle
* Nginx
* Port forwarding
* Local AWS emulation with Floci
* EC2 troubleshooting

## EC2 Mental Model

An EC2 instance is a virtual server running inside AWS.

A typical launch requires:

```text
AMI
  ↓
Instance Type
  ↓
VPC / Subnet
  ↓
Security Group
  ↓
Key Pair
  ↓
Storage
  ↓
EC2 Instance
```

## AMI

AMI stands for:

```text
Amazon Machine Image
```

An AMI defines the operating system and base server image used to launch an EC2 instance.

For the local lab I used:

```text
ami-ubuntu2404-arm64
```

This represented Ubuntu 24.04 for ARM64.

## Instance Type

An instance type defines the compute resources available to an EC2 instance.

Examples include:

```text
t2.micro
t3.micro
t4g.micro
```

Because the selected Ubuntu AMI used ARM64 architecture, I used:

```text
t4g.micro
```

instead of `t2.micro`.

This reinforced an important rule:

```text
AMI architecture
      ↓
must match
      ↓
instance architecture
```

## VPC and Subnet

The local Floci environment created a default VPC:

```text
172.31.0.0/16
```

with subnets such as:

```text
172.31.0.0/20
172.31.16.0/20
172.31.32.0/20
```

I learned that:

* VPC defines the network boundary
* subnet places resources inside a smaller network
* EC2 instances receive private IP addresses inside the subnet

## Security Groups

Security Groups act as virtual firewalls for EC2 instances.

I created a Security Group:

```text
cloud-lab-sg
```

and allowed SSH:

```text
TCP 22
Source: 0.0.0.0/0
```

For a real production server, SSH access should normally be restricted to trusted source IP addresses instead of allowing the entire internet.

Later, I also allowed:

```text
TCP 8080
```

for the Nginx web server.

## Key Pair

I imported an existing Ed25519 public key into the EC2 environment.

Conceptually:

```text
Private key
    ↓
stays on my Mac

Public key
    ↓
installed on the server
```

The private key must never be shared or committed to Git.

## Launching EC2

The instance was launched using the AWS CLI:

```bash
aws ec2 run-instances \
  --image-id ami-ubuntu2404-arm64 \
  --instance-type t4g.micro \
  --count 1 \
  --key-name cloud-lab-ssh \
  --security-group-ids SECURITY_GROUP_ID \
  --subnet-id subnet-default-us-east-1-a
```

## Verifying the Instance

I used:

```bash
aws ec2 describe-instances
```

to inspect information such as:

* instance ID
* state
* AMI
* instance type
* private IP
* Security Group
* key pair

## SSH Connectivity

Floci exposed EC2 SSH through a host port.

Example:

```text
Mac 127.0.0.1:2200
        ↓
Floci/Docker
        ↓
EC2 port 22
        ↓
sshd
```

SSH connection:

```bash
ssh -i ~/.ssh/id_ed25519 -p 2200 ubuntu@127.0.0.1
```

## SSH Host-Key Troubleshooting

After recreating an instance, SSH reported:

```text
REMOTE HOST IDENTIFICATION HAS CHANGED
```

This happened because the new server used a different SSH host key while the same local host and port were reused.

For the local lab, I removed the old entry using:

```bash
ssh-keygen -R "[127.0.0.1]:2200"
```

In a real environment, an unexpected host-key change should be investigated before accepting the new key.

## Installing Nginx

Nginx was installed inside the EC2 instance.

Initially, Nginx could not use port 80 because Floci's EC2 metadata service was already listening there.

The error was:

```text
Address already in use
```

I diagnosed it with:

```bash
sudo ss -tulpn | grep ':80'
```

and found Floci's metadata service using:

```text
169.254.169.254:80
```

I moved Nginx to:

```text
8080
```

and verified:

```bash
curl http://localhost:8080
```

## Floci Port Forwarding

The EC2 container had its own private network address.

Example:

```text
172.17.0.3
```

Nginx worked inside the instance:

```bash
curl http://172.17.0.3:8080
```

but the Mac could not directly reach that Docker network.

After TCP 8080 was allowed in the Security Group, Floci created a forwarding container.

Example:

```text
Mac :30000
    ↓
Floci forwarding
    ↓
EC2 :8080
    ↓
Nginx
```

I successfully tested external access with:

```bash
curl http://127.0.0.1:30000
`
```

