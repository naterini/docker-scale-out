#!/bin/bash
while [ ! -s /etc/slurm/nodes.conf ]
do
	sleep 0.25
done

exit 0
