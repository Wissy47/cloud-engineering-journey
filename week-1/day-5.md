# Day 5 — Linux Server Administration & Troubleshooting

## Objective

Learn how to administer and troubleshoot a Linux server using system health checks, process management, service control, logs, permissions, users, groups, and web-server diagnostics.

## Topics Covered

* CPU, memory, and disk health
* `uptime`, `free`, and `df`
* Process inspection with `ps` and `top`
* Background jobs
* PIDs and Linux signals
* `SIGTERM` vs `SIGKILL`
* Disk usage with `du`
* systemd
* `systemctl`
* `journalctl`
* Nginx service management
* Port conflicts
* Users and groups
* Ownership and permissions
* `chmod` and `chown`
* Numeric permissions
* setgid
* umask
* Nginx access and error logs
* Layer-by-layer troubleshooting

## Server Health Checks

I started by checking system health with:

```bash
uptime
free -h
df -h
```

### Uptime and Load Average

Example:

```text
load average: 0.08, 0.07, 0.03
```

The three numbers represent system load over approximately:

```text
1 minute
5 minutes
15 minutes
```

Low values indicated very little system pressure.

### Memory

I used:

```bash
free -h
```

and learned that `available` memory is often more useful than looking only at `free`.

Linux uses unused RAM for cache, which can be reclaimed when applications need it.

### Disk Space

I checked filesystem usage with:

```bash
df -h
```

and confirmed the server had plenty of free storage.

## Process Monitoring

I inspected processes with:

```bash
ps aux --sort=-%cpu | head
ps aux --sort=-%mem | head
```

Important fields included:

```text
PID
%CPU
%MEM
VSZ
RSS
STAT
COMMAND
```

I also used:

```bash
top
```

to monitor processes in real time.

Important `top` summary fields included:

```text
Tasks
%Cpu(s)
MiB Mem
MiB Swap
```

## Process States

Common process states:

```text
R → running
S → sleeping
Z → zombie
```

A zombie process has already finished but still has a small process-table entry because its parent has not collected its exit status.

## Background Jobs

I created a background process with:

```bash
sleep 500 &
```

Then inspected it with:

```bash
jobs
ps aux | grep '[s]leep'
```

The shell returned both a job number and PID.

Example:

```text
[1] 67
```

where:

```text
1  → shell job number
67 → PID
```

## Signals

I stopped a process gracefully using:

```bash
kill PID
```

This sends:

```text
SIGTERM (15)
```

which allows the process to shut down cleanly.

I also tested:

```bash
kill -9 PID
```

which sends:

```text
SIGKILL (9)
```

and forces immediate termination.

The key rule is:

```text
SIGTERM first
SIGKILL only when necessary
```

## Disk Usage Troubleshooting

I checked which `/var` directories were using the most storage:

```bash
du -sh /var/* 2>/dev/null | sort -h
```

Then drilled further into:

```bash
du -sh /var/lib/* 2>/dev/null | sort -h
```

I learned that `du` is useful for locating unexpectedly large directories when a server disk begins filling up.

## Floci systemd Cloud Image

The original Floci EC2 image did not boot with systemd.

PID 1 was:

```text
tail -f /dev/null
```

This prevented realistic use of:

```text
systemctl
journalctl
```

I built Floci's Ubuntu 24.04 ARM64 cloud image locally and launched:

```text
ami-ubuntu2404-cloud-arm64
```

The new instance successfully showed:

```text
PID 1 = systemd
/sbin/init
```

This provided a much more realistic Ubuntu server-administration environment.

## systemd Troubleshooting

I ran:

```bash
systemctl is-system-running
```

and initially received:

```text
degraded
```

I identified the failed service using:

```bash
systemctl --failed
```

The failed unit was:

```text
systemd-remount-fs.service
```

I inspected it using:

```bash
sudo systemctl status systemd-remount-fs.service --no-pager
sudo journalctl -u systemd-remount-fs.service --no-pager
```

The logs showed:

```text
can't find LABEL=cloudimg-rootfs
```

The cloud image expected a real cloud disk, while Floci used a Docker overlay filesystem.

I confirmed this with:

```bash
cat /etc/fstab
findmnt /
lsblk -f
```

For this local emulator only, I adjusted `/etc/fstab`, reset the failed unit, and restored the system to:

```text
systemctl --failed → 0 failed units
systemctl is-system-running → running
```

## Service Administration

I listed running services with:

```bash
systemctl list-units --type=service --state=running
```

Important services included:

```text
ssh
cron
rsyslog
systemd-journald
systemd-networkd
systemd-resolved
```

## Journald

I inspected recent errors with:

```bash
sudo journalctl -p err -n 20 --no-pager
```

and SSH logs with:

```bash
sudo journalctl -u ssh -n 20 --no-pager
```

I learned that logs are historical and must be interpreted using timestamps and the current service state.

An old error does not necessarily mean the problem still exists.

## Nginx Service Troubleshooting

I installed Nginx and checked:

```bash
systemctl status nginx --no-pager
```

Initially it failed.

The journal showed:

```text
bind() to 0.0.0.0:80 failed
Address already in use
```

I used:

```bash
sudo ss -tulpn | grep ':80'
```

and found Floci's metadata service already listening on:

```text
169.254.169.254:80
```

I changed Nginx to port:

```text
8080
```

Then verified the configuration:

```bash
sudo nginx -t
```

Restarted it:

```bash
sudo systemctl restart nginx
```

and confirmed:

```text
nginx.service → active (running)
```

Finally:

```bash
curl -I http://localhost:8080
```

returned:

```text
HTTP/1.1 200 OK
```

## systemctl Commands Practiced

```bash
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx
sudo systemctl reload nginx
systemctl is-active nginx
systemctl is-enabled nginx
```

Important distinction:

```text
is-active  → Is it running now?
is-enabled → Will it start automatically at boot?
```

## Users and Groups

My user was:

```text
ubuntu
```

with group membership:

```text
ubuntu sudo
```

I created a shared administrative group:

```bash
sudo groupadd webadmins
```

and added `ubuntu`:

```bash
sudo usermod -aG webadmins ubuntu
```

## Ownership

The Nginx web root originally belonged to:

```text
root:root
```

I changed the group ownership to:

```text
root:webadmins
```

using:

```bash
sudo chown -R root:webadmins /var/www/html
```

This means:

```text
owner user  = root
owner group = webadmins
```

It does not mean that root must be a member of `webadmins`.

## Permissions

I practiced symbolic and numeric permissions.

Example:

```text
-rw-r--r-- = 644
```

where:

```text
r = 4
w = 2
x = 1
```

So:

```text
rw- = 6
r-- = 4
r-- = 4
```

I changed a web file to:

```bash
chmod 600 /var/www/html/test.html
```

and Nginx returned:

```text
403 Forbidden
```

because only the owner could read the file.

Restoring:

```bash
chmod 644 /var/www/html/test.html
```

made the page work again.

## Directory Permissions

The web root used:

```text
755
```

which means:

```text
owner  → rwx
group  → r-x
others → r-x
```

For directories, `x` means:

```text
traverse / enter the directory
```

Removing directory execute permission prevented Nginx from reaching the file even when the file itself was readable.

## Shared Web Directory

I configured:

```text
root:webadmins
```

with group write access.

Then enabled setgid:

```bash
sudo chmod g+s /var/www/html
```

The directory became:

```text
drwxrwsr-x
```

The `s` means new files inherit the directory's group.

So newly created files became:

```text
ubuntu:webadmins
```

instead of:

```text
ubuntu:ubuntu
```

## umask

My shell used:

```text
umask 0002
```

I learned that umask removes default permissions.

Typical starting permissions:

```text
files       → 666
directories → 777
```

With `umask 0002`:

```text
files       → 664
directories → 775
```

Combined with setgid, a new directory appeared as:

```text
2775
```

where the leading `2` represents the setgid bit.

## Testing Group Access

I created another user:

```text
webtest
```

and added it to:

```text
webadmins
```

The user successfully created:

```text
webtest:webadmins
```

files inside `/var/www/html`.

After removing `webtest` from the group, the same user received:

```text
Permission denied
```

when attempting to create files.

This proved that group membership was the source of write access.

## Nginx Logs

I inspected:

```text
/var/log/nginx/access.log
/var/log/nginx/error.log
```

### Access Log

Example:

```text
::1 - - [14/Sep/2026:00:13:10 +0000] "GET /test.html HTTP/1.1" 200 41 "-" "curl/8.5.0"
```

Important fields included:

```text
client IP
timestamp
HTTP method
path
HTTP version
status code
response size
referrer
user agent
```

### Status Codes Seen

```text
200 → success
403 → forbidden
404 → not found
```

### Error Log

The error log showed real causes such as:

```text
Address already in use
Permission denied
```

I learned to use access and error logs together:

```text
access.log → what the client experienced
error.log  → why it happened
```

## Final Troubleshooting Challenge

I diagnosed a website reported as unavailable.

I checked:

```bash
systemctl status nginx
sudo ss -tulpn | grep ':8080'
curl -I http://localhost:8080
sudo journalctl -u nginx -n 20 --no-pager
```

All server-side checks were healthy.

The issue was outside the application.

I then checked the Security Group and found that TCP `8080` was not allowed.

After adding the inbound rule, Floci created a forwarding container:

```text
Mac :30000
   ↓
Floci forwarder
   ↓
EC2 :8080
   ↓
Nginx
```

Testing from the Mac:

```bash
curl -I http://127.0.0.1:30000
```

returned:

```text
HTTP/1.1 200 OK
```

## Troubleshooting Workflow

A useful server troubleshooting sequence is:

```text
1. Check system health
2. Check process
3. Check service
4. Check listening port
5. Test locally
6. Inspect logs
7. Check permissions
8. Check Security Group/firewall
9. Check external connectivity
```

## What I Learned

I learned how to operate a Linux server instead of only installing software on it.

The biggest lesson was to troubleshoot layer by layer rather than guessing.

A running EC2 instance does not guarantee that the application is healthy or reachable.

## Lab Outcome

By the end of Day 5, I was able to:

* inspect CPU, RAM, swap, and disk usage
* monitor processes
* manage background jobs
* use Linux signals
* troubleshoot disk usage
* operate systemd services
* inspect journal logs
* diagnose Nginx startup failures
* manage users and groups
* understand ownership and permissions
* use numeric permission modes
* configure setgid
* understand umask
* inspect Nginx access and error logs
* troubleshoot an application from the process layer to external network access

