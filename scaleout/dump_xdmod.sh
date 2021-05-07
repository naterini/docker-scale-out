#!/bin/bash
export TZ=UTC

sacct --allusers --parsable2 --noheader --allocations --duplicates \
	--format jobid,jobidraw,cluster,partition,account,group,gid,user,uid,submit,eligible,start,end,elapsed,exitcode,state,nnodes,ncpus,reqcpus,reqmem,reqtres,reqtres,timelimit,nodelist,jobname \
	--state CANCELLED,COMPLETED,FAILED,NODE_FAIL,PREEMPTED,TIMEOUT \
	--starttime now-1hour --endtime now >> /xdmod/data.csv
