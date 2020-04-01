# slurm-docker-scaleout
Docker compose cluster for testing Slurm

## Prerequisites
  * docker 2019-10-04+
  * docker-compose 1.21+
  * ssh (client)

## Basic Architecture

Maria Database Node:
  * db

Slurm Management Nodes:
  * slurmctld
  * slurmctld2
  * slurmdb
  * slurmdbd

Compute Nodes:
  * node[1-50]

Login Nodes:
  * login

Kibana:
 * View http://localhost:5601/

Elasticsearch:
 * View http://localhost:9200/

## To build and run:

```
make
```

## To build without caching:

```
make nocache
```

## To stop:

```
make stop
```

## To reverse all changes:

```
make clean
```

## To remove all images:

```
make uninstall
```

## To control:

```
make bash
make HOST=node1 bash
```

## To login via ssh
```
ssh-keygen -f "/home/$(whoami)/.ssh/known_hosts" -R "10.11.1.5" 2>/dev/null
ssh -o StrictHostKeyChecking=no -l fred 10.11.1.5 -X #use 'password'
```

## Changes needed for sysctl.conf to make it run:
```
net.core.somaxconn=1024
net.ipv4.tcp_max_syn_backlog=2048
fs.file-max=992832

# Force gc to clean-up quickly
net.ipv4.neigh.default.gc_interval = 3600

# Set ARP cache entry timeout
net.ipv4.neigh.default.gc_stale_time = 3600

# Setup DNS threshold for arp
net.ipv4.neigh.default.gc_thresh3 = 8096
net.ipv4.neigh.default.gc_thresh2 = 4048
net.ipv4.neigh.default.gc_thresh1 = 1024

# Increase map count for elasticsearch
vm.max_map_count=262144

```

## Caveats

IPv6 does not work in Docker currently. All connections must be IPv4.
