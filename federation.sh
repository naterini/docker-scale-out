#!/bin/bash
CLUSTERS="
a 10.21 2001:db8:1:1::
b 10.22 2001:db8:1:2::
c 10.23 2001:db8:1:3::
"
touch scaleout/hosts.nodes
HN=$(readlink -e scaleout/hosts.nodes);
truncate -s0 $HN

function dip() {
	id="$1"
	json="$(docker inspect "$id")"
	h="$(echo "$json" | jq -r '.[].Config.Hostname')"
	ip4="$(echo "$json" | jq -r ".[].NetworkSettings.Networks.${c}_internal.IPAddress")"
	ip6="$(echo "$json" | jq -r ".[].NetworkSettings.Networks.${c}_internal.GlobalIPv6Address")"

	echo "${ip4} ${c}-${h}" >> $HN
	echo "${ip6} ${c}-${h}" >> $HN
}

mkdir -p federation

#choose the lucky host of slurmdbd for all clusters
PDB="$(echo "$CLUSTERS" | awk '/./ {printf "%s-slurmdbd", $1; exit}')"

dbdhosts=$(echo "$CLUSTERS" | awk '
	BEGIN {printf "AccountingStorageExternalHost="; first=1}
	/./ {
			if (!first) {printf ","}
			printf "%s-slurmdbd", $1
			first=0
		}
')

dbdhosts=$(echo "$CLUSTERS" | awk '
	/./ {
			printf "AccountingStorageBackupHost=%s-slurmdbd\n", $1
		}
')

echo "$CLUSTERS" | grep .| while read c SUBNET SUBNET6 trash
do
	export SUBNET SUBNET6

	#bridge="br-$(docker network inspect "b_internal" | jq -r ".[].Id" | cut -b1-12)"

	if [ ! -d federation/$c ]
	then
		echo "cloning git repo contents for cluster $c"
		mkdir -p federation/$c && \
		git ls-files | while read i
		do
			mkdir -p $(dirname "federation/$c/$i")
			[ -f "$i" ] && cp -v "$i" "federation/$c/$i"
		done
		rm -f "federation/$c/scaleout/nodelist"
	fi

	pushd "federation/$c"

	sed -e '/ClusterName=/d' -i scaleout/slurm/slurm.conf
	echo "ClusterName=$c" >> scaleout/slurm/slurm.conf
	sed -e '/AccountingStorageExternalHost=/d' -i scaleout/slurm/slurm.conf
	sed -e '/AccountingStorageBackupHost=/d' -i scaleout/slurm/slurm.conf
	sed -e '/AccountingStorageHost=/d' -i scaleout/slurm/slurm.conf
	echo "AccountingStorageHost=$PDB" >> scaleout/slurm/slurm.conf
	[ -f docker-compose.yml ] && make clean
	make clean

	make SUBNET="$SUBNET" SUBNET6="$SUBNET6" build

	docker-compose ps -q | while read i
	do
		dip $i
	done

	popd
done

s=$(pwd)
# update /etc/hosts without having to restart all hosts
echo "$CLUSTERS" | grep .| while read c SUBNET SUBNET6 trash
do
	export SUBNET SUBNET6
	cat $HN >> "federation/$c/scaleout/hosts.nodes"

	pushd "federation/$c"
	docker-compose ps -q | while read i
	do
		cd $s
		docker cp "federation/$c/scaleout/hosts.nodes" "$i:/etc/hosts.nodes"
		docker exec "$i" bash -c 'cat /etc/hosts.nodes >> /etc/hosts'
	done
	popd
done
