# Week 5 Day 3 — EBS Deep Dive: Attach, Mount, Persistence, Resize, and Recovery

## Objective

Understand how Amazon EBS works as persistent block storage for EC2.

The lab covered:

* Creating a gp3 EBS volume
* Attaching it to an EC2 instance
* Inspecting attachment state
* Understanding block devices and filesystems
* Formatting and mounting storage
* Verifying persistence after unmount/remount
* Understanding real AWS device naming
* Understanding snapshot-based recovery
* Resizing block storage and filesystems
* Identifying Floci EBS limitations

---

## EBS Concept

Amazon EBS provides persistent block storage for EC2.

The storage stack is:

```text
EBS Volume
    ↓
Block Device
    ↓
Filesystem
    ↓
Mount Point
    ↓
Files and Directories
```

An EBS volume is not automatically usable as a filesystem immediately after creation.

It must normally be:

```text
Created
  ↓
Attached
  ↓
Detected by Linux
  ↓
Formatted
  ↓
Mounted
```

---

## Selected EC2 Instance

The lab used:

```text
Instance ID:
i-ba7ea7b81f5c9b519
```

The instance was located in:

```text
Availability Zone:
us-east-1a
```

This mattered because EBS volumes must be in the same Availability Zone as the EC2 instance they attach to.

---

## Create EBS Volume

A 5 GiB gp3 volume was created:

```bash
VOLUME_ID=$(aws ec2 create-volume \
  --availability-zone "$AZ" \
  --size 5 \
  --volume-type gp3 \
  --tag-specifications \
    'ResourceType=volume,Tags=[{Key=Name,Value=week5-day3-data}]' \
  --query 'VolumeId' \
  --output text)
```

Result:

```text
vol-fbd10f42885967978
```

The volume was inspected:

```bash
aws ec2 describe-volumes \
  --volume-ids "$VOLUME_ID" \
  --query 'Volumes[0].[VolumeId,Size,VolumeType,AvailabilityZone,State,Attachments]' \
  --output json
```

Result:

```text
Volume ID: vol-fbd10f42885967978
Size:      5 GiB
Type:      gp3
AZ:        us-east-1a
State:     available
Attachments: []
```

The state:

```text
available
```

meant the volume existed but was not attached to an EC2 instance.

---

## Attach Volume

The volume was attached using:

```bash
aws ec2 attach-volume \
  --volume-id "$VOLUME_ID" \
  --instance-id "$INSTANCE_ID" \
  --device /dev/sdf
```

Initial state:

```text
attaching
```

After attachment:

```text
State: in-use
Device: /dev/sdf
Instance: i-ba7ea7b81f5c9b519
DeleteOnTermination: false
```

The volume attachment existed correctly in the Floci EC2 control plane.

---

## Inspect Linux Block Devices

Inside the instance:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  lsblk
```

No new 5 GiB block device appeared.

This demonstrated an important Floci limitation:

```text
Floci EC2 API:
Volume attached ✅

Linux guest:
Real EBS block device not exposed ❌
```

---

## Real AWS Behavior

On real AWS, an EBS volume attached as:

```text
/dev/sdf
```

may appear inside a Nitro-based EC2 instance as:

```text
/dev/nvme1n1
```

The AWS attachment name and the Linux device name do not always match.

A real workflow would be:

```text
aws ec2 attach-volume
        ↓
lsblk
        ↓
find new block device
        ↓
check filesystem
        ↓
format if new
        ↓
mount
```

---

## Linux EBS Simulation

Because Floci did not expose the EBS volume as a real Linux block device, a loop-backed image was used to simulate the Linux storage layer.

A 5 GiB backing file was created:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  truncate -s 5G /tmp/week5-day3-ebs.img
```

The image was formatted:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  mkfs.ext4 -F /tmp/week5-day3-ebs.img
```

Mount point:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  mkdir -p /mnt/week5-ebs
```

The image was mounted:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  mount -o loop /tmp/week5-day3-ebs.img /mnt/week5-ebs
```

---

## Verify Mounted Storage

Filesystem usage:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  df -h /mnt/week5-ebs
```

Result:

```text
Filesystem   Size   Used   Avail   Mounted on
/dev/loop1   4.9G   24K    4.6G   /mnt/week5-ebs
```

`lsblk` showed:

```text
loop1    5G    /mnt/week5-ebs
```

This simulated what a real attached EBS block device would look like inside Linux.

---

## Persistence Test

Data was written:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  bash -c 'echo "Week 5 Day 3 persistent EBS data" > /mnt/week5-ebs/persistent.txt'
```

A timestamp file was also created:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  bash -c 'date > /mnt/week5-ebs/created-at.txt'
```

The storage was unmounted:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  umount /mnt/week5-ebs
```

Then remounted:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  mount -o loop /tmp/week5-day3-ebs.img /mnt/week5-ebs
```

The file was still present:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  cat /mnt/week5-ebs/persistent.txt
```

Result:

```text
Week 5 Day 3 persistent EBS data
```

This demonstrated:

```text
Unmounting storage
does not delete the data.
```

---

# Snapshot and Recovery Concepts

An EBS snapshot represents a point-in-time backup of an EBS volume.

Conceptually:

```text
EBS Volume
    ↓
Snapshot
    ↓
Restored EBS Volume
    ↓
Attach to EC2
    ↓
Mount filesystem
    ↓
Recover data
```

Snapshots are useful for:

```text
Backup
Recovery
Cloning
Migration
Rollback
Disaster recovery
```

---

## Snapshot Attempt

A snapshot was attempted:

```bash
aws ec2 create-snapshot \
  --volume-id "$VOLUME_ID" \
  --description "Week 5 Day 3 EBS backup"
```

Floci returned:

```text
UnsupportedOperation
Operation CreateSnapshot is not supported.
```

Therefore:

```text
CreateSnapshot ❌
```

was identified as a Floci limitation.

In real AWS, the snapshot would contain the actual EBS filesystem and data.

---

## EBS Resize Concept

Another important operation is increasing storage capacity.

Original:

```text
EBS volume: 5 GiB
Filesystem: 5 GiB
```

After increasing the volume:

```text
EBS volume: 8 GiB
Filesystem: still approximately 5 GiB
```

The filesystem must also be expanded.

Therefore:

```text
Resize block storage
        ≠
Resize filesystem
```

Both operations are required.

---

## AWS ModifyVolume Attempt

The EBS API resize was attempted:

```bash
aws ec2 modify-volume \
  --volume-id "$VOLUME_ID" \
  --size 8
```

Floci returned:

```text
UnsupportedOperation
Operation ModifyVolume is not supported.
```

Therefore:

```text
ModifyVolume ❌
```

was another emulator limitation.

---

# Simulated Linux Resize

The backing image was increased from:

```text
5 GiB
```

to:

```text
8 GiB
```

using:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  truncate -s 8G /tmp/week5-day3-ebs.img
```

The loop device was refreshed:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  losetup -c /dev/loop1
```

`lsblk` now showed:

```text
loop1    8G    /mnt/week5-ebs
```

However:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  df -h /mnt/week5-ebs
```

still showed:

```text
4.9G
```

This demonstrated:

```text
Block device = 8 GiB ✅
Filesystem   = ~5 GiB ❌
```

---

## Expand ext4 Filesystem

The filesystem was expanded online:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  resize2fs /dev/loop1
```

Result:

```text
The filesystem on /dev/loop1 is now
2097152 (4k) blocks long.
```

Filesystem usage was checked again:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  df -h /mnt/week5-ebs
```

Result:

```text
Filesystem   Size   Used   Avail
/dev/loop1   7.8G   32K    7.4G
```

The additional space became available.

---

## Verify Existing Data

The existing file was checked:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  cat /mnt/week5-ebs/persistent.txt
```

Result:

```text
Week 5 Day 3 persistent EBS data
```

This proved the filesystem could be expanded without losing existing data.

---

# Real AWS Resize Workflow

On real AWS:

```text
Original EBS
5 GiB
   ↓
aws ec2 modify-volume --size 8
   ↓
EBS block device becomes 8 GiB
   ↓
Linux detects additional capacity
   ↓
grow partition if necessary
   ↓
resize2fs or xfs_growfs
   ↓
Filesystem uses full 8 GiB
```

For ext4:

```bash
sudo resize2fs /dev/nvme1n1
```

For XFS:

```bash
sudo xfs_growfs /mnt/data
```

If a partition exists, the partition may need to be extended first.

---

# Persistent Mounts

A manual command like:

```bash
mount /dev/nvme1n1 /mnt/data
```

does not automatically survive reboot.

A real AWS Linux instance can use `/etc/fstab` for persistent mounting.

The preferred approach is to mount by filesystem UUID instead of relying only on a device name.

Example:

```bash
sudo blkid /dev/nvme1n1
```

Then:

```text
UUID=<filesystem-uuid> /mnt/data ext4 defaults,nofail 0 2
```

can be added to:

```text
/etc/fstab
```

---

# Safe Detachment

Before detaching a data volume from a running instance:

```bash
sudo umount /mnt/data
```

Then:

```bash
aws ec2 detach-volume \
  --volume-id "$VOLUME_ID"
```

The volume can later be attached to another EC2 instance in the same Availability Zone.

Existing volumes containing data should not be formatted again.

Running:

```bash
mkfs.ext4
```

on an existing filesystem can destroy the existing data.

---

# Auto Scaling Connection

This lab also reinforced why persistent application data should generally not live only on auto-scaled EC2 instances.

Auto Scaling can terminate and replace instances at any time.

A production architecture may instead use:

```text
Database      → RDS / Aurora
Uploads       → S3
Shared files  → EFS
Cache         → ElastiCache
Block storage → EBS where appropriate
```

EC2 instances can then remain disposable while persistent data survives separately.

---

# Floci Limitations Identified

```text
Create EBS volume       ✅
Describe EBS volume     ✅
Attach EBS volume       ✅
Attachment state        ✅
Guest block-device map  ❌
CreateSnapshot          ❌ Unsupported
ModifyVolume            ❌ Unsupported
Linux filesystem lab    ✅ Simulated
Linux persistence       ✅
Linux resize workflow   ✅
```

---

# Key Concepts Learned

* EBS provides persistent block storage for EC2.
* EBS volumes are Availability Zone specific.
* `available` means the volume is not attached.
* `in-use` means the volume is attached.
* AWS device names may differ from Linux-visible device names.
* A raw block device and a filesystem are different layers.
* A new block device must normally be formatted before use.
* Existing data volumes must not be reformatted.
* Mounting makes a filesystem accessible through the Linux directory tree.
* Unmounting does not erase the underlying data.
* EBS snapshots provide recovery points.
* Resizing block storage does not automatically resize the filesystem.
* ext4 can be expanded with `resize2fs`.
* Existing data can survive filesystem expansion.
* `/etc/fstab` can make mounts survive reboot.
* Auto-scaled compute should generally not be the sole location of persistent application state.

---

# Commands Practiced

```bash
aws ec2 create-volume
aws ec2 describe-volumes
aws ec2 attach-volume
aws ec2 create-snapshot
aws ec2 modify-volume

lsblk
df -h
mkfs.ext4
mount
umount
truncate
losetup
resize2fs
blkid
cat
```

---

# Final Result

Successfully demonstrated:

```text
Create gp3 EBS volume          ✅
Attach to EC2                  ✅
Inspect attachment state       ✅
Create filesystem              ✅
Mount filesystem               ✅
Write persistent data          ✅
Unmount/remount persistence    ✅
Resize 5 GiB → 8 GiB           ✅ simulated
Expand ext4 filesystem         ✅
Preserve existing data         ✅
Snapshot concepts              ✅
Snapshot API execution         ❌ Floci limitation
ModifyVolume API execution     ❌ Floci limitation
```

