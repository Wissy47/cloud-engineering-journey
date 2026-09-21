# Week 3 — Day 3: EBS Volumes & Persistent Storage

## Objectives

* Understand what Amazon EBS is
* Understand the difference between compute and storage
* Create and inspect an EBS volume
* Understand Availability Zone requirements
* Understand `DeleteOnTermination`
* Understand block devices and filesystems
* Format storage with `ext4`
* Mount and unmount a filesystem
* Verify that data persists across unmount/remount
* Understand UUID-based mounting with `/etc/fstab`
* Understand Floci limitations compared with real AWS

## What is EBS?

EBS stands for:

**Elastic Block Store**

EBS provides persistent block storage for EC2 instances.

Conceptually:

```text
EC2 instance = compute
EBS volume   = storage
```

An EC2 instance can use one or more EBS volumes.

## Root Volume vs Additional Volume

The root volume normally contains the operating system.

Example:

```text
EC2
├── Root volume
│   └── /
│
└── Additional EBS volume
    └── /data
```

Additional EBS volumes can be used for:

* Application data
* Databases
* Logs
* Uploaded files
* Persistent storage

## Availability Zone Requirement

An EBS volume normally needs to be in the same Availability Zone as the EC2 instance it is attached to.

Example:

```text
EC2: us-east-1a
EBS: us-east-1a
✅ Compatible for attachment
```

while:

```text
EC2: us-east-1a
EBS: us-east-1b
❌ Cannot be directly attached
```

## EBS Volume Created

An 8 GiB `gp3` volume was created in:

```text
us-east-1a
```

Volume ID:

```text
vol-a8d611b531a752583
```

The volume metadata showed:

```text
Size: 8 GiB
Type: gp3
Availability Zone: us-east-1a
State: in-use
```

## Attachment Metadata

Floci reported the EBS volume as attached to:

```text
Instance ID: i-37b688abad3857c2f
Device: /dev/sdf
State: attached
DeleteOnTermination: false
```

## DeleteOnTermination

The attachment showed:

```text
DeleteOnTermination: false
```

This means the volume is intended to remain after the attached EC2 instance is terminated.

Conceptually:

```text
Instance terminated
↓
EBS volume remains
↓
Stored data can still be reused
```

If the value were:

```text
DeleteOnTermination: true
```

the volume would be deleted automatically when the instance is terminated.

## Floci Limitation

Although Floci reported the EBS attachment in its metadata, the attached 8 GiB disk did not appear as an actual Linux block device inside the Docker-backed EC2 container.

The Linux block-device list showed no `/dev/sdf` device.

This highlighted an important distinction between:

```text
Cloud API metadata
↓
EC2 block-device metadata
↓
Actual Linux block device
```

Because the EBS volume was not exposed as a usable Linux block device, a loop-backed filesystem was used to practice the Linux storage workflow.

## Local Block-Storage Simulation

An 8 GiB sparse image file was created:

```bash
truncate -s 8G /tmp/ebs-volume.img
```

The file appeared as:

```text
8.0G /tmp/ebs-volume.img
```

This simulated raw storage.

## Creating an ext4 Filesystem

The storage was formatted using:

```bash
mkfs.ext4 -F /tmp/ebs-volume.img
```

This created an `ext4` filesystem.

The filesystem UUID was:

```text
608973e3-ac67-4284-81a1-81a12eee26fb
```

## Mount Point

A mount point was created:

```bash
mkdir -p /data
```

The filesystem was mounted using:

```bash
mount -o loop /tmp/ebs-volume.img /data
```

Linux exposed it as:

```text
/dev/loop0
```

and mounted it at:

```text
/data
```

## Verifying the Mounted Filesystem

The mounted filesystem was checked using:

```bash
df -h /data
```

The result showed approximately:

```text
7.8G
```

available on `/dev/loop0`.

## Writing Persistent Data

A test file was created:

```bash
echo "Week 3 Day 3 - Persistent EBS data" > /data/cloud-lab.txt
```

Another application-data directory was created:

```bash
mkdir -p /data/application
```

and:

```bash
echo "Application database simulation" \
  > /data/application/database.txt
```

The stored files were:

```text
/data/cloud-lab.txt
/data/application/database.txt
```

## Persistence Test

The filesystem was unmounted:

```bash
umount /data
```

After unmounting, the `/data` directory appeared empty.

The filesystem was then remounted:

```bash
mount -o loop /tmp/ebs-volume.img /data
```

The original files were still present.

This demonstrated that the files belonged to the underlying filesystem, not the mount-point directory itself.

Conceptually:

```text
Mounted storage
↓
Write data
↓
Unmount
↓
Mount point appears empty
↓
Remount storage
↓
Data reappears
```

## Real AWS Equivalent

On real AWS, the workflow would normally be:

```text
Create EBS volume
↓
Attach volume to EC2
↓
Linux detects block device
↓
Format filesystem
↓
Mount filesystem
↓
Write data
```

Typical commands would include:

```bash
aws ec2 attach-volume
lsblk
mkfs.ext4
mount
df
```

The local lab used:

```text
/tmp/ebs-volume.img
→ /dev/loop0
```

only because Floci did not expose the EBS attachment as a real Linux block device.

## UUID and /etc/fstab

The filesystem UUID was obtained with:

```bash
blkid
```

The `/etc/fstab` entry used was:

```text
UUID=608973e3-ac67-4284-81a1-81a12eee26fb /data ext4 defaults 0 2
```

This describes:

```text
UUID      → filesystem identifier
/data     → mount point
ext4      → filesystem type
defaults  → normal mount options
0         → dump configuration
2         → filesystem-check order
```

## Testing /etc/fstab

After recreating the loop-device association, the filesystem was mounted using:

```bash
mount -a
```

The result was verified using:

```bash
df -h /data
```

and:

```bash
cat /data/cloud-lab.txt
```

The persistent data was successfully recovered.

## Important Real-AWS Lesson

In real AWS, using the filesystem UUID in `/etc/fstab` is generally safer than relying only on a device name such as:

```text
/dev/sdf
```

because Linux device names can differ between environments and instance types.

## Key Concepts Learned

* EBS provides persistent block storage
* EC2 compute and EBS storage are separate concepts
* EBS volumes are Availability Zone resources
* EBS volumes should be attached to EC2 instances in the same AZ
* `DeleteOnTermination=false` preserves the volume after instance termination
* A new raw block device normally needs a filesystem before use
* `ext4` is a common Linux filesystem
* Mount points expose filesystems inside the Linux directory tree
* Unmounting does not delete stored data
* Remounting restores access to the same data
* UUIDs are useful for persistent filesystem identification
* `/etc/fstab` defines filesystems that Linux should mount automatically
* `mount -a` tests configured `/etc/fstab` entries
* Floci may emulate cloud metadata more completely than the underlying Linux data plane
