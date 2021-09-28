#!/bin/bash

ssh mgmtnode systemctl restart slurmctld
until ssh mgmtnode 'ps -ef|grep slurmcltd' ; do
sleep 1
done

pdsh systemctl restart slurmd
sleep 3
scontrol update nodename=node[00-09] state=resume 2>/dev/null
