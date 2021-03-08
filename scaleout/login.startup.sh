#!/bin/bash
sed -e '/SLURM/d' -i /etc/pam.d/sshd
munged --num-threads=10
postfix -Dv start
exec /usr/sbin/sshd -D
