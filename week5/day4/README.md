# Week 5 Day 4 — Amazon EFS and Shared Storage

## Objective

Understand how Amazon EFS provides shared network storage that multiple EC2 instances can access at the same time.

The lab covered:

* EFS architecture
* Difference between EBS and EFS
* Creating an EFS filesystem
* Creating mount targets
* Creating an EFS Security Group
* Allowing NFS traffic on TCP port 2049
* Understanding multi-AZ shared storage
* Simulating EFS behavior with a shared Docker volume
* Reading and writing the same files from multiple clients
* Understanding how EFS integrates with Auto Scaling Groups

---

## EBS vs EFS

### EBS

EBS provides block storage.

```text id="40u6ly"
EC2
 |
 v
EBS Volume
```

Typical characteristics:

```text id="qn878c"
Block storage
Usually attached to one instance
AZ-specific
Looks like a disk
Requires filesystem formatting
```

---

### EFS

EFS provides a shared network filesystem.

```text id="j5ezcl"
       EFS
      /   \
     /     \
 EC2 A     EC2 B
```

Typical characteristics:

```text id="q71fsh"
Network filesystem
Multiple EC2 instances
Shared files
Mounted using NFS
Useful across Auto Scaling instances
```

---

## Architecture

The desired architecture was:

```text id="myi3sx"
                    Application Load Balancer
                              |
                 -------------------------
                 |                       |
              EC2 A                   EC2 B
                 \                       /
                  \                     /
                       Amazon EFS
                    Shared filesystem
```

Both EC2 instances can access the same files.

---

## Create EFS Filesystem

An EFS filesystem was created using:

```bash id="yz7tkc"
EFS_ID=$(aws efs create-file-system \
  --creation-token week5-day4-efs \
  --performance-mode generalPurpose \
  --throughput-mode bursting \
  --tags Key=Name,Value=week5-shared-efs \
  --query 'FileSystemId' \
  --output text)
```

The filesystem was inspected using:

```bash id="63xl07"
aws efs describe-file-systems \
  --file-system-id "$EFS_ID"
```

---

## EFS Security Group

A dedicated Security Group was used:

```text id="fwg1ck"
week5-efs-sg
```

The Security Group allowed NFS traffic:

```text id="qbj8a7"
Protocol: TCP
Port: 2049
Source: Backend EC2 Security Group
```

The backend Security Group was:

```text id="4df0bd"
sg-e57859fda5ead5e67
week5-backend-sg
```

This means:

```text id="l7pp4d"
Internet
   X
   |
   EFS

Backend EC2 SG
      |
      | TCP 2049
      v
     EFS
```

EFS was not directly exposed to the internet.

---

## Reusing Existing Security Group

Creating the Security Group returned:

```text id="zi4oia"
InvalidGroup.Duplicate
```

because:

```text id="fqds3m"
week5-efs-sg
```

already existed.

Instead of creating another one, the existing Security Group was discovered and reused.

This reinforced the workflow:

```text id="cy43k8"
Resource already exists
      ↓
Discover resource
      ↓
Inspect resource
      ↓
Reuse resource
```

---

## Mount Targets

Two EFS mount targets were created.

### Mount Target A

```text id="ewjhio"
Mount Target:
fsmt-d7679c5791834380a

Subnet:
subnet-9a4a8120

State:
available
```

### Mount Target B

```text id="il560y"
Mount Target:
fsmt-520bcb895d664d5bb

Subnet:
subnet-9fb59c20

State:
available
```

The mount targets represented access points in both private subnets.

Conceptually:

```text id="17dss4"
                     EFS
                      |
           -------------------------
           |                       |
      Mount Target A          Mount Target B
           |                       |
      Private Subnet A        Private Subnet B
           |                       |
        EC2 A                   EC2 B
```

---

## Floci Mount Target Observation

Both Floci mount targets returned:

```text id="4la6ge"
10.0.0.10
```

This was identified as emulator-specific behavior.

Floci provides the EFS control-plane API but does not provide a real NFSv4.1 data-plane implementation.

Therefore:

```text id="tzk070"
Create EFS            ✅
Create mount targets  ✅
Describe EFS          ✅
Real NFS mount        ❌
```

---

# Shared Storage Simulation

Since Floci does not expose a real EFS NFS endpoint, a Docker shared volume was used to simulate the storage behavior.

A shared volume was created:

```bash id="4s4umb"
docker volume create week5-efs-shared
```

Result:

```text id="nqfa99"
week5-efs-shared
```

The volume was inspected:

```bash id="cod593"
docker volume inspect week5-efs-shared
```

Mountpoint:

```text id="1rggwl"
/var/lib/docker/volumes/week5-efs-shared/_data
```

---

## Client A

A simulated EC2 client was created:

```bash id="5zf1p3"
docker run -dit \
  --name week5-efs-client-a \
  -v week5-efs-shared:/mnt/efs \
  alpine sh
```

---

## Client B

A second simulated EC2 client was created:

```bash id="03h744"
docker run -dit \
  --name week5-efs-client-b \
  -v week5-efs-shared:/mnt/efs \
  alpine sh
```

Both containers mounted:

```text id="hb5t74"
/mnt/efs
```

to the same shared Docker volume.

Architecture:

```text id="kxa7lg"
week5-efs-client-a
        \
         \
       Shared Volume
         /
        /
week5-efs-client-b
```

---

# Shared File Test

Client A created a file:

```bash id="47e0nn"
docker exec week5-efs-client-a \
  sh -c 'echo "Created by Web Server A" > /mnt/efs/shared-file.txt'
```

Client A verified the file:

```bash id="i6yhp5"
docker exec week5-efs-client-a \
  cat /mnt/efs/shared-file.txt
```

Output:

```text id="5dgbzr"
Created by Web Server A
```

---

## Client B Reads Client A's File

Client B executed:

```bash id="f5t9s5"
docker exec week5-efs-client-b \
  cat /mnt/efs/shared-file.txt
```

Result:

```text id="zbo6d5"
Created by Web Server A
```

This confirmed both clients were seeing the same underlying storage.

---

## Client B Updates Shared File

Client B appended:

```bash id="921h10"
docker exec week5-efs-client-b \
  sh -c 'echo "Updated by Web Server B" >> /mnt/efs/shared-file.txt'
```

Client A then read the file:

```bash id="dm3n7s"
docker exec week5-efs-client-a \
  cat /mnt/efs/shared-file.txt
```

Result:

```text id="s38l62"
Created by Web Server A
Updated by Web Server B
```

This demonstrated two-way shared access.

---

# Shared Storage Concept

The test proved:

```text id="ev6wpd"
Server A writes
      ↓
Shared filesystem
      ↓
Server B reads
      ↓
Server B writes
      ↓
Server A reads update
```

Unlike EBS:

```text id="1mu6uv"
EC2 A → its own block storage
EC2 B → its own block storage
```

EFS provides:

```text id="lv0bdt"
EC2 A ─┐
       ├── same filesystem
EC2 B ─┘
```

---

# Real AWS EFS Mounting

On real AWS, Linux would typically install EFS utilities.

For Ubuntu:

```bash id="j50n8k"
sudo apt update
sudo apt install -y amazon-efs-utils
```

A mount directory could be created:

```bash id="6hkfm6"
sudo mkdir -p /mnt/efs
```

Using the EFS helper:

```bash id="tk4eu7"
sudo mount -t efs fs-xxxxxxxx:/ /mnt/efs
```

Or using NFS:

```bash id="f455hn"
sudo mount -t nfs4 \
  -o nfsvers=4.1 \
  fs-xxxxxxxx.efs.us-east-1.amazonaws.com:/ \
  /mnt/efs
```

EFS uses:

```text id="hh229b"
TCP 2049
```

for NFS traffic.

---

# Persistent EFS Mount

EFS can be mounted automatically after reboot using:

```text id="u5tfpg"
/etc/fstab
```

Example:

```text id="ask79k"
fs-xxxxxxxx:/ /mnt/efs efs _netdev,tls 0 0
```

`_netdev` indicates the filesystem depends on network connectivity.

---

# EFS with Auto Scaling

EFS is particularly useful when EC2 instances are managed by an Auto Scaling Group.

Without shared storage:

```text id="de1cbq"
Instance A
└── uploads

Instance B
└── different uploads
```

If Instance A is terminated, locally stored application files may be lost.

With EFS:

```text id="s4av76"
                EFS
             /       \
            /         \
      ASG EC2 A     ASG EC2 B
```

The storage survives independently of individual EC2 instances.

If Auto Scaling replaces:

```text id="qrmybd"
EC2 A
```

with:

```text id="bopjlv"
EC2 C
```

the new instance can mount the same EFS filesystem.

---

# Common EFS Use Cases

EFS can be useful for:

```text id="b7azwl"
Shared web uploads
CMS media directories
Shared application assets
Shared configuration
Home directories
Legacy applications requiring filesystem access
Container shared storage
```

---

# EBS vs EFS Summary

```text id="b121kk"
EBS
-----------------------
Block storage
Usually one EC2 instance
AZ-specific
Looks like a disk
ext4/XFS
High-performance block workloads


EFS
-----------------------
Shared filesystem
Multiple EC2 instances
Network-based
NFS
Shared directories/files
Ideal for horizontally scaled servers
```

---

# Key Concepts Learned

* EFS provides shared network storage.
* Multiple EC2 instances can mount the same EFS filesystem.
* EFS uses NFS over TCP port 2049.
* Mount targets provide VPC connectivity to EFS.
* A dedicated EFS Security Group should restrict NFS access to trusted clients.
* EFS can work across multiple Availability Zones.
* EFS storage exists independently of EC2 instances.
* EFS is useful with Auto Scaling Groups.
* Shared storage prevents individual EC2 instances from owning critical shared files.
* EBS and EFS solve different storage problems.
* Local AWS emulators may support control-plane APIs without implementing the full storage data plane.

---

# Commands Practiced

```bash id="367gwk"
aws efs create-file-system
aws efs describe-file-systems
aws efs create-mount-target
aws efs describe-mount-targets

aws ec2 create-security-group
aws ec2 describe-security-groups
aws ec2 authorize-security-group-ingress

docker volume create
docker volume inspect
docker run
docker exec
cat
```

---

# Final Result

Successfully demonstrated:

```text id="58we4u"
EFS filesystem                  ✅
EFS mount targets               ✅
Multi-subnet architecture       ✅
Dedicated EFS Security Group    ✅
NFS TCP 2049 concept            ✅
Shared filesystem simulation    ✅
Client A writes                 ✅
Client B reads                  ✅
Client B writes                 ✅
Client A sees update            ✅
Real NFS mount in Floci         ❌ emulator limitation
```