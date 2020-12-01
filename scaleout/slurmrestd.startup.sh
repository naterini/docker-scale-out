#!/bin/bash
while true
do
	#wait until config is filled out by controller before starting
	grep node00 /etc/slurm/slurm.conf 2>&1 >/dev/null
	[ $? -eq 0 ] && sleep 1 && break
	sleep 0.25
done

#ensure there is never any auth provided to slurmrestd
unset SLURM_JWT

while true
do
	/usr/local/sbin/slurmrestd -f /etc/slurm/slurm.jwt.conf \
		-u slurmrestd -g slurmrestd -a rest_auth/jwt \
		-s openapi/v0.0.36,openapi/dbv0.0.36 -vvvvvv \
		${SUBNET}.1.6:80
done
