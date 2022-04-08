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
  * mgmtnode
  * mgmtnode2
  * slurmdbd

Compute Nodes:
  * node[00-09]

Login Nodes:
  * login

Nginx Proxy node:
 * proxy

Rest API Nodes:
  * rest

Kibana:
  * View http://localhost:5601/

Elasticsearch:
  * View http://localhost:9200/

Grafana:
  * View http://localhost:3000/
  * User: admin
  * Password: admin

Open On-Demand:
  * View http://localhost:8081/
  * User: {user name - "fred" or "wilma"}
  * Password: password

Open XDMoD:
  * View http://localhost:8082/

Proxy:
  * Auth REST API http://localhost:8080/auth
  * Query REST API http://localhost:8080/slurm/

## Multiple Instances
Each cluster must have a unique class B subnet.

Default IPv4 is SUBNET="10.11".
Default IPv6 is SUBNET6="2001:db8:1:1::".

## Custom Nodes

Custom node lists may be provided by setting NODELIST to point to a file
containing list of nodes for the cluster or modifing the default generated
"nodelist" file in the scaleout directory.

The node list follows the following format with one node per line:
> ${HOSTNAME} ${IPv4} ${IPv6}

Example line:
> node00 10.11.5.0 2001:db8:1:1::5:0

Note that the service nodes can not be changed and will always be placed into
the following subnets:
> ${SUBNET}.1.0/24
> ${SUBNET6}1:0/122

## To build images

```
git submodule update --init --force --remote --recursive
make build
```

## To run:

```
make
```

## To build and run in Cloud mode:

```
make cloud
```

Note: cloud mode will run in the foreground.

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
## IPv6 configuration

IPv6 must be configured in docker: https://docs.docker.com/config/daemon/ipv6/

## Changes needed for sysctl.conf to make it run:
```
net.ipv4.tcp_max_syn_backlog=4096
net.core.netdev_max_backlog=1000
net.core.somaxconn=15000
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

# Avoid running out of file descriptors
fs.file-max=10000000
fs.inotify.max_user_instances=65535
fs.inotify.max_user_watches=1048576
```

## Caveats

The number of CPU threads on the host are multiplied by the number of nodes. Do not attempt to use computationally intensive applications.

## Docker work-arounds:

```
ERROR: Pool overlaps with other one on this address space
```
Call this:
```
docker-compose down
docker network prune -f
sudo systemctl restart docker
```

## To save all images to ./scaleout.tar

```
make save
```

## To load saved copy of all images

```
make load
```

## How to trigger manual xdmod data dump:

```
make HOST=scaleout_mgmtnode_1 bash
bash /etc/cron.hourly/dump_xdmod.sh
exit
make bash
exec bash /etc/cron.hourly/dump_xdmod.sh
make HOST=xdmod bash
sudo -u xdmod -- /usr/bin/xdmod-shredder -r scaleout -f slurm -i /xdmod/data.csv
sudo -u xdmod -- /usr/bin/xdmod-ingestor
exit
```

## How to disable buidling xdmod container

This is will only disable attempts to build and start the container.

```
export DISABLE_XDMOD=1
```

## Docker may have issues with Cgroup v2

Add these settings to the docker configuration: /etc/docker/daemon.json
```
{
  "exec-opts": [
    "native.cgroupdriver=systemd"
  ],
  "features": {
    "buildkit": true
  },
  "experimental": true,
  "cgroup-parent": "docker.slice",
  "default-cgroupns-mode": "host",
  "storage-driver": "overlay2"
}
```

## Kernel arguments to select cgroup version

Run with Cgroup v2:
```
GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1 systemd.legacy_systemd_cgroup_controller=0"
```

Run with Cgroup v1:
```
GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=0 systemd.legacy_systemd_cgroup_controller=0"
```
