# Week 4 Day 5 — DNS and Network Troubleshooting

## Objective

Learn how to troubleshoot AWS networking systematically instead of changing configurations randomly.

## VPC DNS Settings

VPC:

`vpc-c1d0eaf8`

DNS support:

```text
enableDnsSupport = true
```

DNS hostnames were initially disabled:

```text
enableDnsHostnames = false
```

DNS hostnames were then enabled for the lab.

## NAT Gateway

```text
NAT Gateway:
nat-23913eaf6d8356963

State:
available

Subnet:
subnet-f8d5a80c
```

## Public NACL

Custom NACL:

```text
acl-4df6f0c6e5ee0d486
```

Rules:

### Inbound

```text
100    ALLOW TCP 80
32767  DENY all
```

### Outbound

```text
100    ALLOW TCP 1024-65535
32767  DENY all
```

## Troubleshooting Order

When a connection fails, check:

1. Application/service
2. IP configuration
3. DNS
4. Route table
5. Internet Gateway or NAT Gateway
6. Network ACL
7. Security Group
8. Operating system firewall

## Application Checks

Check listening ports:

```bash
ss -tulpn
```

Check HTTP locally:

```bash
curl -I http://127.0.0.1
```

If localhost fails, the application itself may be the problem.

## DNS Checks

Inspect resolver configuration:

```bash
cat /etc/resolv.conf
```

Inspect resolver state:

```bash
resolvectl status
```

Test DNS:

```bash
getent hosts example.com
```

```bash
nslookup example.com
```

```bash
dig example.com
```

## Connectivity Checks

Test IP reachability:

```bash
ping 8.8.8.8
```

Test TCP connectivity:

```bash
nc -zv <IP_ADDRESS> 80
```

Test HTTP:

```bash
curl -I http://<IP_ADDRESS>
```

Inspect routing:

```bash
ip route
```

```bash
ip route get 8.8.8.8
```

## Important Diagnostic Pattern

If:

```text
ping 8.8.8.8 works
DNS name resolution fails
```

then the network path is likely working and DNS should be investigated.

If both fail, routing, gateway, security controls, or broader network connectivity may be the cause.

## HTTP vs HTTPS Example

Current NACL allows:

```text
TCP 80
```

but does not allow:

```text
TCP 443
```

Therefore:

```text
HTTP  → allowed
HTTPS → blocked by NACL
```

even if the Security Group allows both ports.

## Key Lessons

* DNS problems and routing problems are not the same thing.
* A Security Group allowing traffic does not guarantee connectivity.
* NACL rules can still block allowed Security Group traffic.
* Route tables determine where traffic goes.
* IGWs and NAT Gateways provide different internet paths.
* The application must actually be listening on the expected port.
* Troubleshooting should proceed layer by layer.
