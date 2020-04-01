#!/bin/bash

DISTRO="centos:7.6.1810"

#IPLIST="$(seq -f " 10.11.5.%0.0f" 1 250) $(seq -f " 10.11.6.%0.0f" 1 250)"
IPLIST="$(seq -f " 10.11.5.%0.0f" 1 10)"

printip() {
	for ip in $IPLIST
	do
		name=$(printf "node%02d" $i)
		i=$(($i + 1))

		echo "      - \"$name:$ip\""
	done
}

HOSTLIST="    extra_hosts:
      - \"db:10.11.1.3\"
      - \"slurmdbd:10.11.1.2\"
      - \"mgmtnode:10.11.1.1\"
      - \"mgmtnode2:10.11.1.4\"
      - \"login:10.11.1.5\"
      - \"es01:10.11.1.15\"
      - \"es02:10.11.1.16\"
      - \"es03:10.11.1.17\"
      - \"kibana:10.11.1.18\"
$(printip)"

LOGGING="
    logging:
      driver: syslog
    cap_add:
      - SYS_PTRACE
      - SYS_NICE
    security_opt:
      - seccomp:unconfined
      - apparmor:unconfined
"
# disable Linux specific options
[ $MAC ] && LOGGING=

cat <<EOF
---
version: "3.4"
networks:
  internal:
    driver: bridge
    ipam:
      config:
        -
          subnet: 10.11.0.0/16
volumes:
  root-home:
  home:
  etc-slurm:
  slurmctld:
  elastic_data01:
  elastic_data02:
  elastic_data03:
  mail:
services:
  es01:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.4.2
    container_name: es01
    environment:
      - node.name=es01
      - cluster.name=scaleout
      - discovery.seed_hosts=es02,es03
      - cluster.initial_master_nodes=es01,es02,es03
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - elastic_data01:/usr/share/elasticsearch/data
      - /dev/log:/dev/log
    networks:
      internal:
        ipv4_address: 10.11.1.15
    ports:
      - 9200:9200
$LOGGING
  es02:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.4.2
    container_name: es02
    environment:
      - node.name=es02
      - cluster.name=scaleout
      - discovery.seed_hosts=es01,es03
      - cluster.initial_master_nodes=es01,es02,es03
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - elastic_data02:/usr/share/elasticsearch/data
      - /dev/log:/dev/log
    networks:
      internal:
        ipv4_address: 10.11.1.16
    depends_on:
      - "es01"
$LOGGING
  es03:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.4.2
    container_name: es03
    environment:
      - node.name=es03
      - cluster.name=scaleout
      - discovery.seed_hosts=es01,es02
      - cluster.initial_master_nodes=es01,es02,es03
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - elastic_data03:/usr/share/elasticsearch/data
      - /dev/log:/dev/log
    networks:
      internal:
        ipv4_address: 10.11.1.17
    depends_on:
      - "es01"
$LOGGING
  kibana:
    container_name: kibana
    image: docker.elastic.co/kibana/kibana:7.4.2
    volumes:
      - /dev/log:/dev/log
    environment:
      - SERVER_NAME=scaleout
      - ELASTICSEARCH_HOSTS=http://es01:9200
    networks:
      internal:
        ipv4_address: 10.11.1.18
    ports:
      - 5601:5601
    depends_on:
      - "es01"
      - "es02"
      - "es03"
$LOGGING
  db:
    container_name: db
    build:
      context: ./scaleout
      args:
        DOCKER_FROM: $DISTRO
      network: host
    image: scaleout:latest
    volumes:
      - root-home:/root
      - etc-slurm:/etc/slurm
      - /dev/log:/dev/log
    command: ["bash", "-c", "/usr/bin/mysql_install_db --skip-name-resolve --defaults-file=/etc/my.cnf && exec mysqld_safe --defaults-file=/etc/my.cnf --init-file=/etc/mysql.init"]
    hostname: db
$LOGGING
    networks:
      internal:
        ipv4_address: 10.11.1.3
$HOSTLIST
  slurmdbd:
    container_name: slurmdbd
    image: scaleout:latest
    command: ["bash", "-c", "slurmdbd.startup.sh"]
    hostname: slurmdbd
    networks:
      internal:
        ipv4_address: 10.11.1.2
    volumes:
      - root-home:/root
      - etc-slurm:/etc/slurm
      - /dev/log:/dev/log
      - mail:/var/spool/mail/
$LOGGING
    depends_on:
      - "db"
$HOSTLIST
  mgmtnode:
    container_name: mgmtnode
    image: scaleout:latest
    command: ["bash", "-xv", "/usr/local/bin/slurmctld.startup.sh"]
    hostname: mgmtnode
    networks:
      internal:
        ipv4_address: 10.11.1.1
    volumes:
      - root-home:/root
      - home:/home/
      - slurmctld:/var/spool/slurm
      - etc-slurm:/etc/slurm
      - /dev/log:/dev/log
      - mail:/var/spool/mail/
$LOGGING
$LOGGING
    depends_on:
      - "db"
      - "slurmdbd"
$HOSTLIST
  mgmtnode2:
    container_name: mgmtnode2
    image: scaleout:latest
    command: ["bash", "-xv", "/usr/local/bin/slurmctld.startup.sh"]
    hostname: mgmtnode2
    networks:
      internal:
        ipv4_address: 10.11.1.4
    volumes:
      - root-home:/root
      - etc-slurm:/etc/slurm
      - home:/home/
      - slurmctld:/var/spool/slurm
      - /dev/log:/dev/log
      - mail:/var/spool/mail/
$LOGGING
$LOGGING
    depends_on:
      - "db"
      - "slurmdbd"
      - "mgmtnode"
$HOSTLIST
  login:
    container_name: login
    image: scaleout:latest
    command: ["bash", "-xv", "/usr/local/bin/login.startup.sh"]
    hostname: login
    networks:
      internal:
        ipv4_address: 10.11.1.5
    volumes:
      - root-home:/root
      - etc-slurm:/etc/slurm
      - home:/home/
      - slurmctld:/var/spool/slurm
      - /dev/log:/dev/log
      - mail:/var/spool/mail/
$LOGGING
$LOGGING
    depends_on:
      - "mgmtnode"
$HOSTLIST
EOF

lastname="mgmtnode"
oi=0
for ip in $IPLIST
do
	oi=$(($oi + 1))
	[ $oi -gt 10 -a ! -z "$name" ] && oi=0 && lastname="$name"
	name=$(printf "node%02d" $i)
	i=$(($i + 1))
cat <<EOF
  $name:
    container_name: $name
    image: scaleout:latest
    command: ["bash", "/usr/local/bin/slurmd.startup.sh"]
    hostname: $name
    networks:
      internal:
        ipv4_address: $ip
    volumes:
      - root-home:/root
      - etc-slurm:/etc/slurm
      - /sys/fs/cgroup:/sys/fs/cgroup
      - home:/home/
      - /dev/log:/dev/log
      - mail:/var/spool/mail/
$LOGGING
$LOGGING
    depends_on:
      - "db"
      - "slurmdbd"
      - "$lastname"
$HOSTLIST
EOF

done
