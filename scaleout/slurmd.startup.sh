#!/bin/bash
munged --num-threads=10
/usr/sbin/sshd

while true
do
	#wait until config is filled out by controller before starting
	grep node00 /etc/slurm/slurm.conf 2>&1 >/dev/null
	[ $? -eq 0 ] && sleep 1 && break
	sleep 0.25
done

while true
do
	/usr/local/sbin/slurmd -D -N $(hostname -s)
done
