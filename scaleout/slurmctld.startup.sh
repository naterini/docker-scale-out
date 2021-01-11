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
	props="$(slurmd -C | head -1 | sed 's#NodeName=mgmtnode ##g')"
	for ((i=0;i<10;i++))
	do
		name=$(printf "node%02d" $i)
		echo "NodeName=$name $props" >> /etc/slurm/slurm.conf
	done
else
	while true
	do
		#wait until config is filled out by primary before starting
		grep node00 /etc/slurm/slurm.conf 2>&1 >/dev/null
		[ $? -eq 0 ] && sleep 1 && break
		sleep 0.25
	done
fi

exit 0
