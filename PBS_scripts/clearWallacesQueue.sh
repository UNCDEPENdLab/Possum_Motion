#!/usr/bin/env bash

PATH="$PATH:/usr/local/packages/torque/2.4.16/bin/"
ncpus=12
running=
held=
torls=

function numRunning { 
   running="$(qstat -B | awk '(/[0-9]/){print $5}')" 
}
function numHeld    {
   held="$(qstat -B | awk '(/[0-9]/){print $6}')"
}
function nextHeld {
   torls="$(qstat |awk -F'.' '(/ H batch/){print $1;exit}')"
}


numHeld
numRunning

while [ -n $held  ]; do 
   echo $held held, $running running;
   
   while [ $running -lt $ncpus ]; do
     echo $running running
     
     nextHeld

     echo releaseing $torls
     # free one that is held
     # and wait for the queue to catch up
     qrls $torls

     # possum eats up 12% of the ram in the first 3mins, then drops down to 3.7
     sleep 400;

     # get new number running
     numRunning
   done

   # panic if too much is running
   numRunning
   [ $running -gt $ncpus ] && exit

   # poll ever 10minutes
   echo "Sleeping for 10min"
   sleep 600s

   # update how many are held
   numHeld

done

