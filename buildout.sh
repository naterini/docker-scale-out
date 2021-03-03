#!/bin/bash

DISTRO="centos:8"
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
	GRAFANA_PORTS="
    ports:
      - 3000:3000
"
	ONDEMAND_PORTS="
    ports:
      - 8081:80
"
else
	ES_PORTS=
	KIBANA_PORTS=
	PROXY_PORTS=
	GRAFANA_PORTS=
fi

SUBNET=${SUBNET:-"10.11"}
SUBNET6=${SUBNET6:-"2001:db8:1:1::"}
#generate list of 10 nodes
NODELIST=$(seq 0 9 | while read i
do
	echo "$(printf "node%02d" $i) ${SUBNET}.5.${i} ${SUBNET6}5:${i}"
done)

printip() {
	echo "$NODELIST" | while read name ip4 ip6
	do
		echo "      - \"$name:$ip4\""
		echo "      - \"$name:$ip6\""
	done
}

HOSTLIST="    extra_hosts:
      - \"db:${SUBNET}.1.3\"
      - \"db:${SUBNET6}1:3\"
      - \"slurmdbd:${SUBNET}.1.2\"
      - \"slurmdbd:${SUBNET6}1:2\"
      - \"mgmtnode:${SUBNET}.1.1\"
      - \"mgmtnode:${SUBNET6}1:1\"
      - \"mgmtnode2:${SUBNET}.1.4\"
      - \"mgmtnode2:${SUBNET6}1:4\"
      - \"login:${SUBNET}.1.5\"
      - \"login:${SUBNET6}1:5\"
      - \"rest:${SUBNET}.1.6\"
      - \"rest:${SUBNET6}1:6\"
      - \"proxy:${SUBNET}.1.7\"
      - \"es01:${SUBNET}.1.15\"
      - \"es01:${SUBNET6}1:15\"
      - \"es02:${SUBNET}.1.16\"
      - \"es02:${SUBNET6}1:16\"
      - \"es03:${SUBNET}.1.17\"
      - \"es03:${SUBNET6}1:17\"
      - \"kibana:${SUBNET}.1.18\"
      - \"kibana:${SUBNET6}1:18\"
      - \"influxdb:${SUBNET}.1.19\"
      - \"influxdb:${SUBNET6}1:19\"
      - \"grafana:${SUBNET}.1.20\"
      - \"grafana:${SUBNET6}1:20\"
      - \"open-ondemand:${SUBNET}.1.21\"
      - \"open-ondemand:${SUBNET6}1:21\"
$(printip)"

LOGGING="
    logging:
      driver: journald
    cap_add:
      - SYS_PTRACE
      - SYS_ADMIN
      - MKNOD
      - SYS_NICE
      - SYS_RESOURCE
    security_opt:
      - seccomp:unconfined
      - apparmor:unconfined
"
SYSDFSMOUNTS="
      - /tmp/
      - /run/
      - /run/lock/
      - /etc/localtime:/etc/localtime:ro
      - /sys/:/sys/:ro
      - /sys/firmware
      - /sys/kernel
      - /sys/fs/cgroup/:/sys/fs/cgroup/:ro
      - /sys/fs/cgroup/systemd
      - /sys/fs/fuse/:/sys/fs/fuse/
      - /var/lib/journal
"
# disable Linux specific options
[ $MAC ] && LOGGING=

cat <<EOF
---
version: "3.8"
networks:
  internal:
    driver: bridge
    driver_opts:
        com.docker.network.bridge.enable_ip_masquerade: 'true'
    internal: false
    enable_ipv6: true
    ipam:
      config:
        - subnet: "${SUBNET}.0.0/16"
        - subnet: "${SUBNET6}/64"
volumes:
  root-home:
  home:
  etc-ssh:
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
        SUBNET: "$SUBNET"
        SUBNET6: "$SUBNET6"
      network: host
    image: scaleout:latest
    environment:
      - SUBNET="${SUBNET}"
      - SUBNET6="${SUBNET6}"
    volumes:
      - root-home:/root
      - etc-slurm:/etc/slurm
      - /dev/log:/dev/log
    command: ["bash", "-c", "/usr/bin/mysql_install_db --skip-name-resolve --defaults-file=/etc/my.cnf && exec mysqld_safe --defaults-file=/etc/my.cnf --init-file=/etc/mysql.init --syslog "]
    hostname: db
$LOGGING
    networks:
      internal:
        ipv4_address: "${SUBNET}.1.3"
        ipv6_address: "${SUBNET6}1:3"
$HOSTLIST
  slurmdbd:
    image: scaleout:latest
    environment:
      - SUBNET="${SUBNET}"
      - SUBNET6="${SUBNET}"
    hostname: slurmdbd
    networks:
      internal:
        ipv4_address: "${SUBNET}.1.2"
        ipv6_address: "${SUBNET6}1:2"
    volumes:
      - root-home:/root
      - etc-slurm:/etc/slurm
      - /dev/log:/dev/log
      - mail:/var/spool/mail/
$SYSDFSMOUNTS
$LOGGING
    depends_on:
      - "db"
$HOSTLIST
  mgmtnode:
    image: scaleout:latest
    environment:
      - SUBNET="${SUBNET}"
      - SUBNET6="${SUBNET6}"
      - container=docker
    hostname: mgmtnode
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.1
        ipv6_address: ${SUBNET6}1:1
    volumes:
      - root-home:/root
      - home:/home/
      - slurmctld:/var/spool/slurm
      - etc-ssh:/etc/ssh
      - etc-slurm:/etc/slurm
      - /dev/log:/dev/log
      - mail:/var/spool/mail/
      - auth:/auth/
$SYSDFSMOUNTS
$LOGGING
    depends_on:
      - "slurmdbd"
$HOSTLIST
  mgmtnode2:
    image: scaleout:latest
    environment:
      - SUBNET="${SUBNET}"
      - SUBNET6="${SUBNET6}"
      - container=docker
    hostname: mgmtnode2
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.4
        ipv6_address: ${SUBNET6}1:4
    volumes:
      - root-home:/root
      - etc-ssh:/etc/ssh
      - etc-slurm:/etc/slurm
      - home:/home/
      - slurmctld:/var/spool/slurm
      - /dev/log:/dev/log
      - mail:/var/spool/mail/
$SYSDFSMOUNTS
$LOGGING
    depends_on:
      - "slurmdbd"
      - "mgmtnode"
$HOSTLIST
  login:
    image: scaleout:latest
    environment:
      - SUBNET="${SUBNET}"
      - SUBNET6="${SUBNET6}"
      - container=docker
    hostname: login
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.5
        ipv6_address: ${SUBNET6}1:5
    volumes:
      - root-home:/root
      - etc-ssh:/etc/ssh
      - etc-slurm:/etc/slurm
      - home:/home/
      - slurmctld:/var/spool/slurm
      - /dev/log:/dev/log
      - mail:/var/spool/mail/
$SYSDFSMOUNTS
$LOGGING
$HOSTLIST
EOF

lastname="mgmtnode"
oi=0
echo "$NODELIST" | while read name ip4 ip6
do
	oi=$(($oi + 1))
	i=$(($i + 1))
cat <<EOF
  $name:
    image: scaleout:latest
    environment:
      - SUBNET="${SUBNET}"
      - SUBNET6="${SUBNET6}"
      - container=docker
    hostname: $name
    networks:
      internal:
        ipv4_address: $ip4
        ipv6_address: $ip6
    volumes:
      - root-home:/root
      - etc-ssh:/etc/ssh
      - etc-slurm:/etc/slurm
      - home:/home/
      - /dev/log:/dev/log
      - mail:/var/spool/mail/
$SYSDFSMOUNTS
    ulimits:
      nproc:
        soft: 65535
        hard: 65535
      nofile:
        soft: 131072
        hard: 131072
      memlock:
        soft: -1
        hard: -1
$LOGGING
    depends_on:
      - "$lastname"
$HOSTLIST
EOF

	[ $oi -gt 10 -a ! -z "$name" ] && oi=0 && lastname="$name"
done

cat <<EOF
  open-ondemand:
    build:
      context: ./open-ondemand
      network: host
    image: open-ondemand
    environment:
      - SUBNET="${SUBNET}"
      - SUBNET6="${SUBNET6}"
      - DEFAULT_SSHHOST=login
    volumes:
      - /dev/log:/dev/log
      - etc-ssh:/etc/shared-ssh
      - home:/home/
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.21
        ipv6_address: ${SUBNET6}1:21
    depends_on:
      - "login"
$ONDEMAND_PORTS
$LOGGING
  influxdb:
    build:
      context: ./influxdb
      network: host
    image: influxdb
    command: ["bash", "-c", "/setup.sh & source /entrypoint.sh"]
    environment:
      - SUBNET="${SUBNET}"
      - SUBNET6="${SUBNET6}"
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=user
      - DOCKER_INFLUXDB_INIT_PASSWORD=password
      - DOCKER_INFLUXDB_INIT_ORG=scaleout
      - DOCKER_INFLUXDB_INIT_BUCKET=scaleout
      - DOCKER_INFLUXDB_INIT_RETENTION=1w
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=token
      - DOCKER_INFLUXDB_INIT_USER_ID=
      - INFLUXDB_DATA_QUERY_LOG_ENABLED=true
      - INFLUXDB_REPORTING_DISABLED=false
      - INFLUXDB_HTTP_LOG_ENABLED=true
      - INFLUXDB_CONTINUOUS_QUERIES_LOG_ENABLED=true
      - LOG_LEVEL=debug
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - /dev/log:/dev/log
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.19
        ipv6_address: ${SUBNET6}1:19
$LOGGING
  grafana:
    image: grafana
    build:
      context: ./grafana
      network: host
    environment:
      - SUBNET="${SUBNET}"
      - SUBNET6="${SUBNET6}"
    volumes:
      - /dev/log:/dev/log
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.20
        ipv6_address: ${SUBNET6}1:20
$GRAFANA_PORTS
$LOGGING
  es01:
    image: docker.elastic.co/elasticsearch/elasticsearch-oss:7.10.1
    environment:
      - node.name=es01
      - cluster.name=scaleout
      - discovery.seed_hosts=es02,es03
      - cluster.initial_master_nodes=es01,es02,es03
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - SUBNET="${SUBNET}"
      - SUBNET6="${SUBNET6}"
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
        ipv6_address: ${SUBNET6}1:15
${ES_PORTS}
$LOGGING
  es02:
    image: docker.elastic.co/elasticsearch/elasticsearch-oss:7.10.1
    environment:
      - node.name=es02
      - cluster.name=scaleout
      - discovery.seed_hosts=es01,es03
      - cluster.initial_master_nodes=es01,es02,es03
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - SUBNET="${SUBNET}"
      - SUBNET6="${SUBNET6}"
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
        ipv6_address: ${SUBNET6}1:16
$LOGGING
  es03:
    image: docker.elastic.co/elasticsearch/elasticsearch-oss:7.10.1
    environment:
      - node.name=es03
      - cluster.name=scaleout
      - discovery.seed_hosts=es01,es02
      - cluster.initial_master_nodes=es01,es02,es03
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - SUBNET="${SUBNET}"
      - SUBNET6="${SUBNET6}"
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
        ipv6_address: ${SUBNET6}1:17
$LOGGING
  kibana:
    image: docker.elastic.co/kibana/kibana-oss:7.10.1
    volumes:
      - /dev/log:/dev/log
    environment:
      - SERVER_NAME=scaleout
      - ELASTICSEARCH_HOSTS=http://es01:9200
      - SUBNET="${SUBNET}"
      - SUBNET6="${SUBNET6}"
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.18
        ipv6_address: ${SUBNET6}1:18
${KIBANA_PORTS}
    depends_on:
      - "es01"
      - "es02"
      - "es03"
$LOGGING
  rest:
    hostname: rest
    image: scaleout:latest
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.6
        ipv6_address: ${SUBNET6}1:6
    volumes:
      - etc-ssh:/etc/ssh
      - etc-slurm:/etc/slurm
      - /dev/log:/dev/log
$SYSDFSMOUNTS
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
      - SUBNET="${SUBNET}"
      - SUBNET6="${SUBNET6}"
      - container=docker
    hostname: proxy
    command: ["bash", "-c", "nginx & php-fpm7 -F"]
    networks:
      internal:
        ipv4_address: ${SUBNET}.1.7
        ipv6_address: ${SUBNET6}1:7
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

