#!/bin/bash
munged --num-threads=10
postfix -Dv start
exec /usr/sbin/sshd -D
