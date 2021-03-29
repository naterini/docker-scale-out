#!/bin/bash
#only configure once
[ -f /var/run/slurmctld.startup ] && exit 0
touch /var/run/slurmctld.startup

for ((i=1;i<=100;i++))
do
	sacctmgr show cluster &>/dev/null
	[ $? -eq 0 ] && break
	[ $i -eq 99 ] && echo echo "slurmdbd never started" && exit 127
	sleep 5
done

CLUSTERNAME="$(awk -F= '/^ClusterName=/ {print $2}' /etc/slurm/slurm.conf)"
[ -z "$CLUSTERNAME" ] && echo 'no cluster name' && exit 1
sacctmgr -vi add cluster "$CLUSTERNAME"
sacctmgr -vi add account bedrock Cluster="$CLUSTERNAME" Description="none" Organization="none"
sacctmgr -vi add user root Account=bedrock DefaultAccount=bedrock

for i in arnold bambam barney betty chip dino edna fred gazoo pebbles wilma
do
	sacctmgr -vi add user $i Account=bedrock DefaultAccount=bedrock
done

if [ "$(hostname -s)" = "mgmtnode" ]
then
	if [ ! -s /etc/slurm/nodes.conf ]
	then
		props="$(slurmd -C | head -1 | sed 's#NodeName=mgmtnode ##g')"
		echo "NodeName=DEFAULT $props" >> /etc/slurm/nodes.conf

		cat /etc/nodelist | while read name ip4 ip6
		do
			[ ! -z "$ip6" ] && addr="$ip6" || addr="$ip4"
			echo "NodeName=$name NodeAddr=$addr" >> /etc/slurm/nodes.conf
		done
	fi
else
	while [ ! -s /etc/slurm/nodes.conf ]
	do
		sleep 0.25
	done
fi

exit 0
