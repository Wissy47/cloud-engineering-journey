# Week 6 Day 3 — Docker Networking

## Objective

Understand how Docker networking works and how containers communicate with:

- the Docker host
- other containers
- user-defined networks
- Docker DNS
- published ports

Topics covered:

- Default bridge network
- User-defined bridge networks
- Container IP addresses
- Multiple networks per container
- Container-to-container communication
- Docker DNS
- Host-to-container communication
- Published ports
- Network isolation
- Disconnecting and reconnecting containers
- Networking troubleshooting

---

# Docker Network Types

Docker provides several built-in network types.

The available networks were inspected using:

```bash
docker network ls
```

The environment contained networks including:

```text
bridge
host
none
floci_default
week6-network
```

The main networks used during this lab were:

```text
bridge
week6-network
```

---

# Default Bridge Network

Containers started without a specific network normally use Docker's default:

```text
bridge
```

Conceptually:

```text
Docker Host
    |
    v
bridge network
    |
    +---- Container A
    |
    +---- Container B
```

The default bridge provides basic container networking.

However, user-defined bridge networks are generally more useful for multi-container applications because they provide better isolation and automatic DNS-based container-name resolution.

---

# Inspect Networks

The Docker networks were listed:

```bash
docker network ls
```

The default bridge network can be inspected:

```bash
docker network inspect bridge
```

A formatted inspection can be used:

```bash
docker network inspect bridge \
  --format 'Name={{.Name}} Driver={{.Driver}} Subnet={{(index .IPAM.Config 0).Subnet}} Gateway={{(index .IPAM.Config 0).Gateway}}'
```

---

# Web Container Network Configuration

The existing web container was:

```text
week6-day2-web
```

Its network configuration was inspected:

```bash
docker inspect week6-day2-web \
  --format 'NetworkMode={{.HostConfig.NetworkMode}} IP={{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
```

Output:

```text
NetworkMode=bridge
IP=172.17.0.20172.21.0.2
```

The IP addresses were displayed together because no separator was included in the format string.

The container was actually connected to:

```text
bridge        -> 172.17.0.20
week6-network -> 172.21.0.2
```

A clearer command was:

```bash
docker inspect week6-day2-web \
  --format '{{range $name, $network := .NetworkSettings.Networks}}{{$name}} -> {{$network.IPAddress}}{{println}}{{end}}'
```

---

# Multiple Networks

A Docker container can belong to multiple networks simultaneously.

The web container demonstrated:

```text
                    week6-day2-web
                      /          \
                     /            \
                    v              v
             bridge network   week6-network
              172.17.0.20      172.21.0.2
```

This allows one container to participate in different communication paths.

---

# Create User-Defined Network

A custom network was created:

```bash
docker network create week6-network
```

Verification:

```bash
docker network ls | grep week6
```

The network could then be inspected:

```bash
docker network inspect week6-network
```

---

# Connect Existing Container

The web container was connected to the custom network:

```bash
docker network connect \
  week6-network \
  week6-day2-web
```

The container remained connected to its original bridge network as well.

---

# Create Client Container

A second container was created:

```bash
docker run -d \
  --name week6-client \
  --network week6-network \
  alpine:latest \
  sleep infinity
```

This created:

```text
week6-network
├── week6-day2-web
└── week6-client
```

The client container was assigned:

```text
172.21.0.3
```

while the web container used:

```text
172.21.0.2
```

---

# Install curl in Client Container

The client needed curl for HTTP testing:

```bash
docker exec week6-client \
  apk add --no-cache curl
```

---

# Inspect Network Membership

The custom network was inspected:

```bash
docker network inspect week6-network \
  --format '{{range $id, $c := .Containers}}{{$c.Name}} -> {{$c.IPv4Address}}{{println}}{{end}}'
```

Result:

```text
week6-day2-web -> 172.21.0.2/16
week6-client   -> 172.21.0.3/16
```

This confirmed both containers were connected to the same user-defined bridge network.

---

# Docker DNS

Docker provides name resolution for containers on a user-defined network.

DNS resolution was tested:

```bash
docker exec week6-client \
  getent hosts week6-day2-web
```

Result:

```text
172.21.0.2 week6-day2-web
```

This demonstrated:

```text
week6-day2-web
       |
       v
Docker DNS
       |
       v
172.21.0.2
```

Container names can therefore be used instead of hardcoded IP addresses.

---

# Why Container Names Are Better

Container IP addresses can change.

For example:

```text
old IP:
172.21.0.2

future recreated container:
172.21.0.5
```

Hardcoding:

```text
172.21.0.2
```

would break.

Using:

```text
week6-day2-web
```

allows Docker DNS to resolve the current address.

This is why multi-container applications commonly use names such as:

```text
db
redis
api
web
```

rather than fixed IP addresses.

---

# Container-to-Container HTTP

HTTP communication was tested:

```bash
docker exec week6-client \
  curl http://week6-day2-web
```

The request successfully returned the application page:

```text
Week 6 Day 2
Docker Image Version 2
```

Traffic flow:

```text
week6-client
      |
      | http://week6-day2-web
      v
Docker DNS
      |
      v
172.21.0.2
      |
      v
Nginx :80
```

No host-published port was required for this communication.

---

# Ping Test

Network connectivity was also tested:

```bash
docker exec week6-client \
  ping -c 3 week6-day2-web
```

The hostname resolved to:

```text
172.21.0.2
```

and packets were successfully returned.

This confirmed basic network connectivity between the two containers.

---

# Host vs Container Networking

The application was accessible from the Mac using:

```bash
curl http://localhost:8088
```

This path was:

```text
Mac
 |
 | localhost:8088
 v
Docker port publishing
 |
 v
week6-day2-web:80
```

---

# Internal Container Networking

Another container used:

```bash
curl http://week6-day2-web
```

This path was:

```text
week6-client
      |
      v
week6-network
      |
      v
Docker DNS
      |
      v
week6-day2-web:80
```

This does not use:

```text
localhost:8088
```

---

# Published Ports vs Internal Ports

The web container was published with:

```text
-p 8088:80
```

Meaning:

```text
Host port:      8088
Container port: 80
```

Host traffic uses:

```text
localhost:8088
```

Container-to-container traffic uses:

```text
week6-day2-web:80
```

---

# Understanding localhost

`localhost` always refers to the current host or network namespace.

On the Mac:

```text
localhost
=
Mac
```

Inside `week6-client`:

```text
localhost
=
week6-client
```

Inside `week6-day2-web`:

```text
localhost
=
week6-day2-web
```

Therefore:

```text
localhost
```

inside `week6-client` does not refer to the web container.

---

# Network Isolation Test

The web container was disconnected from the custom network:

```bash
docker network disconnect \
  week6-network \
  week6-day2-web
```

The network was inspected again:

```bash
docker network inspect week6-network \
  --format '{{range $id, $c := .Containers}}{{$c.Name}} -> {{$c.IPv4Address}}{{println}}{{end}}'
```

Only:

```text
week6-client
```

remained.

---

# DNS Failure After Disconnect

DNS resolution was tested:

```bash
docker exec week6-client \
  getent hosts week6-day2-web
```

No result was returned.

HTTP communication was tested:

```bash
docker exec week6-client \
  curl --max-time 3 http://week6-day2-web
```

Result:

```text
curl: (6) Could not resolve host: week6-day2-web
```

This confirmed that Docker DNS resolution depended on shared network membership.

---

# Host Access Still Worked

Even after disconnecting the web container from `week6-network`, this still worked:

```bash
curl http://localhost:8088
```

Why?

The published host port remained active through the container's original bridge networking.

Therefore:

```text
custom network disconnect
        ≠
remove published host port
```

---

# Independent Communication Paths

The lab demonstrated two independent paths.

## Internal container path

```text
week6-client
      |
      v
week6-network
      |
      v
week6-day2-web
```

When disconnected:

```text
❌ communication failed
```

---

## Host path

```text
Mac
 |
 v
localhost:8088
 |
 v
published port
 |
 v
week6-day2-web:80
```

This remained:

```text
✅ available
```

---

# Reconnect Container

The web server was reconnected:

```bash
docker network connect \
  week6-network \
  week6-day2-web
```

DNS resolution returned:

```bash
docker exec week6-client \
  getent hosts week6-day2-web
```

Result:

```text
172.21.0.2 week6-day2-web
```

HTTP communication also worked again:

```bash
docker exec week6-client \
  curl http://week6-day2-web
```

---

# Network Membership Controls Connectivity

The lab demonstrated:

```text
Same user-defined network
        |
        v
Docker DNS
        |
        v
container communication
```

When there is no shared network:

```text
No shared network
        |
        v
network isolation
        |
        v
communication fails
```

---

# Default Bridge vs User-Defined Bridge

A useful comparison:

```text
Default bridge
-------------------------------
basic Docker networking
default container attachment
less convenient service discovery


User-defined bridge
-------------------------------
application-specific isolation
Docker DNS
container-name resolution
easy container-to-container communication
```

For multi-container applications, user-defined networks are preferred.

---

# Docker DNS

Docker DNS provides:

```text
container name
       |
       v
container network IP
```

Example:

```text
week6-day2-web
       |
       v
172.21.0.2
```

This allows application configuration such as:

```text
API_HOST=api
DB_HOST=db
REDIS_HOST=redis
```

rather than hardcoded IP addresses.

---

# Networking Troubleshooting Workflow

Useful commands include:

```bash
docker network ls
```

```bash
docker network inspect NETWORK
```

```bash
docker inspect CONTAINER
```

```bash
docker exec CONTAINER \
  getent hosts TARGET
```

```bash
docker exec CONTAINER \
  ping TARGET
```

```bash
docker exec CONTAINER \
  curl http://TARGET
```

Conceptually:

```text
Cannot reach service
      |
      v
Check container running
      |
      v
Check network membership
      |
      v
Check DNS resolution
      |
      v
Check ping/connectivity
      |
      v
Check application port
```

---

# Knowledge Check Summary

## Default vs User-Defined Network

User-defined networks provide better isolation and built-in name-based discovery.

---

## Why DNS Worked

Both containers shared:

```text
week6-network
```

so Docker DNS resolved:

```text
week6-day2-web
```

to its network IP.

---

## Why Names Are Preferred

Names are more stable than container IP addresses.

---

## Port Publishing

```text
-p 8088:80
```

means:

```text
Host 8088
   |
   v
Container 80
```

---

## Container Communication

Containers on the same custom network can communicate using:

```text
container-name:container-port
```

---

## localhost

`localhost` refers to the current container or host.

---

## Network Isolation

Removing a shared network connection prevents direct communication over that network.

---

## Multiple Networks

A single container can connect to multiple Docker networks simultaneously.

---

# Day 3 Mental Model

```text
Host → Container
uses published ports
```

while:

```text
Container → Container
uses Docker networks
+
Docker DNS
+
internal container ports
```

And:

```text
Same network
→ communication possible

Different isolated networks
→ communication blocked
```

---

# Final Result

Successfully demonstrated:

```text
Inspect Docker networks               ✅
Default bridge networking             ✅
Container IP inspection               ✅
Create custom network                 ✅
Connect existing container            ✅
Multiple networks per container       ✅
Create client container               ✅
Docker DNS                            ✅
Container-name resolution             ✅
Container-to-container HTTP           ✅
Ping connectivity                     ✅
Host port publishing                  ✅
Internal vs external ports            ✅
Network isolation                     ✅
Disconnect container                  ✅
DNS failure after disconnect          ✅
Host access remains available         ✅
Reconnect network                     ✅
Restore communication                 ✅
```
