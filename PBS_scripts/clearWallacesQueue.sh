#!/usr/bin/env bash

running=
held=

function numRunning { 
   running="$(qstat -B | awk '(/[0-9]/){print $5}')" 
}
function numHeld    {
   held="$(qstat -B | awk '(/[0-9]/){print $6}')"
}


numHeld
numRunning

while [ -n $held  ]; do 
   echo $held held;
   
   while [ $running -lt 5 ]; do
     echo $running running
     torelease="$(qstat |awk -F'.' '(/ H batch/){print $1;exit}')"

     echo releaseing $torelease
     # free one that is held
     qrls $torelease

     # give it a chance to register
     sleep 2;
     # get new number running
     numRunning
   done

   # poll ever 5minutes
   sleep 300s
   # update how many are held
   numHeld

done

