#!/bin/bash

DISTRO="centos:7.6.1810"
if [ -z "$SUBNET" ]
then
	ES_PORTS="
    ports:
      - 9200:9200
"
	KIBANA_PORTS="
    ports:
      - 5601:5601
"
	PROXY_PORTS="
    ports:
      - 8080:8080
"
fi

SUBNET=${SUBNET:-"10.11"}

#IPLIST="$(seq -f " ${SUBNET}.5.%0.0f" 1 250) $(seq -f " ${SUBNET}.6.%0.0f" 1 250)"
IPLIST="$(seq -f " ${SUBNET}.5.%0.0f" 1 10)"

printip() {
	for ip in $IPLIST
	do
		name=$(printf "node%02d" $i)
		i=$(($i + 1))

		echo "      - \"$name:$ip\""
	done
}

HOSTLIST="    extra_hosts:
      - \"db:${SUBNET}.1.3\"
      - \"slurmdbd:${SUBNET}.1.2\"
      - \"mgmtnode:${SUBNET}.1.1\"
      - \"mgmtnode2:${SUBNET}.1.4\"
      - \"login:${SUBNET}.1.5\"
      - \"rest:${SUBNET}.1.6\"
      - \"proxy:${SUBNET}.1.7\"
      - \"es01:${SUBNET}.1.15\"
      - \"es02:${SUBNET}.1.16\"
      - \"es03:${SUBNET}.1.17\"
      - \"kibana:${SUBNET}.1.18\"
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
    driver_opts:
        com.docker.network.bridge.enable_ip_masquerade: 'true'
    internal: false
    ipam:
      config:
        - subnet: ${SUBNET}.0.0/16
volumes:
  root-home:
  home:
  etc-slurm:
  slurmctld:
  elastic_data01:
  elastic_data02:
  elastic_data03:
  mail:
  auth:
services:
  db:
    build:
      context: ./scaleout
      args:
        DOCKER_FROM: $DISTRO
        SUBNET: $SUBNET
      network: host
    image: scaleout:latest
    environment:
      - SUBNET=${SUBNET}
    volumes:
      - root-home:/root
      - etc-slurm:/etc/slurm
      - /dev/log:/dev/log
    command: ["bash", "-c", "/usr/bin/mysql_install_db --skip-name-resolve --defaults-file=/etc/my.cnf && exec mysqld_safe --defaults-file=/etc/my.cnf --init-file=/etc/mysql.init --syslog "]
    hostname: db
$LOGGING
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.3
$HOSTLIST
  slurmdbd:
    image: scaleout:latest
    environment:
      - SUBNET=${SUBNET}
    command: ["bash", "-c", "slurmdbd.startup.sh"]
    hostname: slurmdbd
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.2
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
    image: scaleout:latest
    environment:
      - SUBNET=${SUBNET}
    command: ["bash", "-xv", "/usr/local/bin/slurmctld.startup.sh"]
    hostname: mgmtnode
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.1
    volumes:
      - root-home:/root
      - home:/home/
      - slurmctld:/var/spool/slurm
      - etc-slurm:/etc/slurm
      - /dev/log:/dev/log
      - mail:/var/spool/mail/
      - auth:/auth/
$LOGGING
    depends_on:
      - "slurmdbd"
$HOSTLIST
  mgmtnode2:
    image: scaleout:latest
    environment:
      - SUBNET=${SUBNET}
    command: ["bash", "-xv", "/usr/local/bin/slurmctld.startup.sh"]
    hostname: mgmtnode2
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.4
    volumes:
      - root-home:/root
      - etc-slurm:/etc/slurm
      - home:/home/
      - slurmctld:/var/spool/slurm
      - /dev/log:/dev/log
      - mail:/var/spool/mail/
$LOGGING
    depends_on:
      - "slurmdbd"
      - "mgmtnode"
$HOSTLIST
  login:
    image: scaleout:latest
    environment:
      - SUBNET=${SUBNET}
    command: ["bash", "-xv", "/usr/local/bin/login.startup.sh"]
    hostname: login
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.5
    volumes:
      - root-home:/root
      - etc-slurm:/etc/slurm
      - home:/home/
      - slurmctld:/var/spool/slurm
      - /dev/log:/dev/log
      - mail:/var/spool/mail/
$LOGGING
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
    image: scaleout:latest
    environment:
      - SUBNET=${SUBNET}
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
    depends_on:
      - "$lastname"
$HOSTLIST
EOF

done

cat <<EOF
  es01:
    image: docker.elastic.co/elasticsearch/elasticsearch-oss:7.6.1
    environment:
      - node.name=es01
      - cluster.name=scaleout
      - discovery.seed_hosts=es02,es03
      - cluster.initial_master_nodes=es01,es02,es03
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - SUBNET=${SUBNET}
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - elastic_data01:/usr/share/elasticsearch/data
      - /dev/log:/dev/log
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.15
${ES_PORTS}
$LOGGING
  es02:
    image: docker.elastic.co/elasticsearch/elasticsearch-oss:7.6.1
    environment:
      - node.name=es02
      - cluster.name=scaleout
      - discovery.seed_hosts=es01,es03
      - cluster.initial_master_nodes=es01,es02,es03
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - SUBNET=${SUBNET}
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - elastic_data02:/usr/share/elasticsearch/data
      - /dev/log:/dev/log
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.16
$LOGGING
  es03:
    image: docker.elastic.co/elasticsearch/elasticsearch-oss:7.6.1
    environment:
      - node.name=es03
      - cluster.name=scaleout
      - discovery.seed_hosts=es01,es02
      - cluster.initial_master_nodes=es01,es02,es03
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - SUBNET=${SUBNET}
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - elastic_data03:/usr/share/elasticsearch/data
      - /dev/log:/dev/log
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.17
$LOGGING
  kibana:
    image: docker.elastic.co/kibana/kibana-oss:7.6.1
    volumes:
      - /dev/log:/dev/log
    environment:
      - SERVER_NAME=scaleout
      - ELASTICSEARCH_HOSTS=http://es01:9200
      - SUBNET=${SUBNET}
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.18
${KIBANA_PORTS}
    depends_on:
      - "es01"
      - "es02"
      - "es03"
$LOGGING
  rest:
    hostname: rest
    image: scaleout:latest
    command: ["bash", "-xv", "/usr/local/bin/slurmrestd.startup.sh"]
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.6
    volumes:
      - etc-slurm:/etc/slurm
      - /dev/log:/dev/log
$LOGGING
    depends_on:
      - "mgmtnode"
$HOSTLIST
  proxy:
    build:
      context: ./proxy
      network: host
    image: proxy:latest
    environment:
      - SUBNET=${SUBNET}
    hostname: proxy
    command: ["bash", "-c", "nginx & php-fpm7 -F"]
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.7
    volumes:
      - auth:/auth/
      - /dev/log:/dev/log
$LOGGING
${PROXY_PORTS}
    depends_on:
      - "rest"
$HOSTLIST
EOF

exit 0

