#!/bin/bash
while true
do
	#wait until config is filled out by controller before starting
	grep node00 /etc/slurm/slurm.conf 2>&1 >/dev/null
	[ $? -eq 0 ] && sleep 1 && break
	sleep 0.25
done

exit 0
