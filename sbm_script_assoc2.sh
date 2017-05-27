#!/bin/sh

function queue {
  QUEUE="$QUEUE $1"
  NUM=$((NUM+1))
}

function regeneratequeue {

  OLDREQUEUE=$QUEUE
  QUEUE=""
  NUM=0
  for PID in $OLDREQUEUE
  do
    if [ -d /proc/$PID ] ; then
      QUEUE="$QUEUE $PID"
      NUM=$((NUM+1))
    fi
  done  
}

function checkqueue {
  OLDCHQUEUE=$QUEUE
  for PID in $OLDCHQUEUE
  do
    if [ ! -d /proc/$PID ] ; then
      regeneratequeue
      break
    fi
  done  
}

#default parameters
NUM=0
QUEUE=""
MAX_PROC=1

P=( 6 5.75 5.5 5.25 5 4.75 4.5)
Q=( 0 0.25 0.5 0.75 1 1.25 1.5)

arrayinds=${!P[*]}

for i in $arrayinds; do
	th sbm.lua -gpunum $1 -L 32 -nclasses 2 -N 1000 -q ${Q[i]} -p ${P[i]} -sq 0 -path /scratch/sbm &
	PID=$!
	queue $PID
	while [ $NUM -ge $MAX_PROC ] ; do
  		checkqueue
  		sleep 0.4
	done
done

	

