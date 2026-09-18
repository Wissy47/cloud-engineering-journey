# Week 3 — Day 1: EC2 Fundamentals & Instance Lifecycle

## Objectives

- Understand the EC2 instance lifecycle
- Inspect instance states
- Reboot an instance
- Stop and start an instance
- Understand the `pending` state
- Terminate a disposable instance
- Understand which lifecycle actions preserve the instance ID

## Existing Instances

Public EC2:

`i-59f24c4f29bf400be`

Private EC2:

`i-b3c6e729388c12973`

Both started the lab in:

`running`

## EC2 Lifecycle

Typical states:

```text
pending
↓
running
↓
stopping
↓
stopped

### Starting a stopped instance:

stopped
↓
pending
↓
running

Termination:

running/stopped
↓
shutting-down
↓
terminated
Reboot Test

The public EC2 instance was rebooted.

After reboot:

Instance ID remained i-59f24c4f29bf400be
State returned to running
The same logical EC2 instance continued to exist

Key lesson:

A reboot restarts the operating system but does not create a new EC2 instance.

Stop/Start Test

The public instance was stopped.

Observed lifecycle:

running
↓
stopping
↓
stopped

It was then started again:

stopped
↓
pending
↓
running

The instance ID remained:

i-59f24c4f29bf400be

Key lesson:

Stop/start preserves the EC2 instance identity.

In real AWS, an automatically assigned public IPv4 address may change after stop/start.

Pending State

pending is a temporary startup state.

It occurs after:

Launching a new instance
Starting a stopped instance

During this stage AWS is preparing compute, storage, networking and the operating system.

Termination Test

A disposable instance was launched:

i-b1a0fd579c95d3b46

It was then terminated.

Final state:

terminated

Observed lifecycle:

running
↓
shutting-down
↓
terminated

Key lesson:

A terminated instance cannot be started again.

A replacement requires launching a new EC2 instance with a new instance ID.

Lifecycle Comparison
Reboot
Restarts the OS
Same instance
Same instance ID
Stop
Shuts down the instance
Can be started again
Same instance ID
Start
Boots a stopped instance
Goes through pending
Returns to running
Terminate
Permanently ends the instance
Cannot be restarted
Replacement requires a new instance
Key Concepts Learned
pending = starting up
running = active
stopping = shutting down toward stopped state
stopped = powered off but recoverable
shutting-down = terminating
terminated = permanently finished
Reboot does not change instance identity
Stop/start preserves instance identity
Termination does not