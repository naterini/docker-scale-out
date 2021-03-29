#!/bin/bash
while true
do
	#wait until config is filled out by primary before starting
	grep node00 /etc/slurm/slurm.conf 2>&1 >/dev/null
	[ $? -eq 0 ] && sleep 1 && break
	sleep 0.25
done

scontrol token username=slurm lifespan=9999999 | sed 's#SLURM_JWT=##g' > /auth/slurm
chmod 0755 -R /auth

sed -e '/^hosts:/d' -i /etc/nsswitch.conf
echo 'hosts:      files dns myhostname' >> /etc/nsswitch.conf

exit 0
