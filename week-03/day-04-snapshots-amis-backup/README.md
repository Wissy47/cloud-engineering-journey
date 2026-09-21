# Week 3 — Day 4: Snapshots, AMIs & Backup

## Objectives

* Understand EBS snapshots
* Understand how snapshots are used for recovery
* Understand incremental snapshots
* Understand AMIs
* Create a custom AMI
* Launch a new EC2 instance from a custom AMI
* Understand the difference between snapshots and AMIs
* Understand basic backup and recovery strategy
* Compare real AWS behavior with Floci behavior

## EBS Snapshots

An EBS snapshot is a point-in-time backup of an EBS volume.

Conceptually:

```text
EBS Volume
    ↓
Snapshot
    ↓
Restored EBS Volume
```

Snapshots are useful when the goal is to recover stored data rather than recreate an entire server.

## Snapshot Recovery Workflow

A typical recovery process is:

```text
Original EBS Volume
        ↓
     Snapshot
        ↓
Create New EBS Volume
        ↓
Attach to EC2
        ↓
Mount Filesystem
        ↓
Recover Data
```

On real AWS, a snapshot can be created using:

```bash
aws ec2 create-snapshot \
  --volume-id "$EBS_VOLUME_ID" \
  --description "Week 3 Day 4 EBS backup"
```

A replacement volume can then be created from the snapshot:

```bash
aws ec2 create-volume \
  --snapshot-id "$SNAPSHOT_ID" \
  --availability-zone us-east-1a \
  --volume-type gp3
```

Because the volume already contains a filesystem restored from the snapshot, it should normally be mounted rather than formatted again.

Running `mkfs` on a restored filesystem could destroy the recovered data.

## Floci Snapshot Limitation

The AWS snapshot API was tested using:

```bash
aws ec2 create-snapshot
```

Floci returned:

```text
UnsupportedOperation
Operation CreateSnapshot is not supported.
```

Therefore, EBS snapshot functionality was studied conceptually rather than fully reproduced in the local Floci environment.

## Incremental Snapshots

EBS snapshots are incremental after the initial snapshot.

Conceptually:

```text
Snapshot 1
→ initial written blocks

Data changes

Snapshot 2
→ changed blocks only

More data changes

Snapshot 3
→ newly changed blocks only
```

Although later snapshots only store changed blocks, each snapshot can still be used to restore a complete volume.

AWS manages the snapshot dependencies internally.

## Amazon Machine Images

An AMI is a reusable image used to launch EC2 instances.

AMI stands for:

**Amazon Machine Image**

An AMI can represent:

* Operating system
* Root filesystem state
* Installed software
* Configuration
* Boot configuration

Conceptually:

```text
Configured EC2
     ↓
Create AMI
     ↓
Reusable Image
     ↓
Launch New EC2
```

## AMI vs Launch Configuration

An AMI does not contain every EC2 launch setting.

The AMI mainly describes the machine image.

Other settings are selected when launching the instance, including:

* Instance type
* Subnet
* Security groups
* IAM role
* Key pair
* Public IP behavior
* User Data

Conceptually:

```text
AMI
= machine image

Launch parameters
= where and how the machine runs
```

A Launch Template can be used when both the image and common EC2 launch settings need to be reusable.

## Custom AMI Created

A custom AMI was created from:

```text
Instance:
i-37b688abad3857c2f
```

The resulting AMI was:

```text
AMI ID:
ami-19e6ea348547095a9

Name:
week3-day4-cloud-lab-ami

Architecture:
arm64

State:
available

Root device:
/dev/xvda
```

## Launching from the Custom AMI

A new instance was launched using the custom AMI.

Result:

```text
Instance:
i-1e7ed1a876c4e1f05

AMI:
ami-19e6ea348547095a9

Instance Type:
t4g.micro

State:
running

Subnet:
subnet-6cdbaae2
```

This demonstrated that the AMI could be used as a launch source.

## Floci AMI Behavior

The filesystem of the original instance was modified before the AMI was created.

Files such as:

```text
/tmp/week3-day2-userdata.txt
/opt/cloud-lab/index.html
```

were expected to appear on the new instance if the AMI represented a full disk image.

However, those files were not present.

Therefore, in this Floci environment:

```text
AMI metadata
→ reproduced

Runtime filesystem changes
→ not reproduced
```

This differs from real AWS behavior.

## Real AWS AMI Behavior

For an EBS-backed EC2 instance, a real AWS AMI uses EBS snapshots of the instance volumes behind the scenes.

Conceptually:

```text
EC2 Instance
├── Root EBS
└── Additional EBS
        ↓
    Create AMI
        ↓
AMI + EBS snapshots
        ↓
Launch new EC2
        ↓
Restored disk state
```

Therefore, filesystem changes included in the AMI should normally be available on EC2 instances launched from that AMI.

## Snapshot vs AMI

The simplest distinction is:

```text
Snapshot
→ storage recovery

AMI
→ server reproduction
```

If the goal is to recover only important files from a data volume:

```text
Use an EBS snapshot
```

If the goal is to reproduce a configured EC2 server:

```text
Use an AMI
```

## Using Both

If an application requires both server recovery and data recovery, a common strategy is:

```text
AMI
→ server reproduction

EBS Snapshots
→ application/data recovery
```

Together:

```text
AMI + EBS snapshots
→ rebuild server
→ restore application data
```

This separation is useful because server configuration and application data may need different backup schedules.

For example:

```text
Server AMI:
created occasionally

Database/data snapshots:
created frequently
```

## Backup Strategy

A backup strategy should answer questions such as:

* What needs to be backed up?
* How frequently should backups be created?
* How long should backups be retained?
* Where should backups be stored?
* How quickly must recovery happen?
* How will backups be tested?

Backups should not only exist — recovery should also be tested.

## Key Concepts Learned

* EBS snapshots provide point-in-time storage backups
* Snapshots are incremental after the first snapshot
* Snapshots can be used to create replacement EBS volumes
* AMIs are reusable EC2 machine images
* AMIs do not contain every EC2 launch parameter
* Launch Templates can store reusable launch configuration
* EBS-backed AMIs rely on snapshots in real AWS
* Snapshots are best suited for storage recovery
* AMIs are best suited for server reproduction
* AMIs and snapshots are often used together
* Backup schedules should reflect how frequently different data changes
* Floci does not fully reproduce all real AWS snapshot and AMI behavior
