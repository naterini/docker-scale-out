#!/bin/bash

# Add hosts in the not crazy slow manner
cat /etc/hosts.nodes >> /etc/hosts

#start systemd
exec /lib/systemd/systemd --system --log-level=info --crash-reboot --log-target=journal-or-kmsg
