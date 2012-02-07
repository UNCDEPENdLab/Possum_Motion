#!/usr/bin/env bash

# Master script, dispatches qsub in blocks of 16 (lower number gets priority in queueing?)
# 
#    o environment is read from environment.sh
#    -- BatchedSize is defined by #PBS -l nproc= in queue.sh (probably always 16)
#    
#    o simID is unique to combination of 
#       - motionFile  --- deterimined by '*motion'
#       - activeFile  --- deterimined by 'act_**.nii.gz
#          o expects act_**_time to exist also
#
#    o possum logs to   simID/logs/
#    o possum output to simID/possum_
#    o combined outs to simID/combined
#    o final nii as     simID/Brain_${simID}.nii.gz
#
#    note: log/1 <=> --procid=0 <=> $simID/possum_0
#

# load TotalCPUs, blocked
source $HOME/Possum-02-2012/PBS_scripts/environment.sh

# e.g. activation_test_3vol.nii.gz
#      contriubtes  'test_3vol' to simID
ActiveFiles=($(ls $VARDIR/act*.nii.gz))

# e.g. zeromotion
#      contributes  'zero'      to simID
MotionFiles=($(ls $VARDIR/*motion))
echo "=> using ${#ActiveFiles[*]} Active Files"
echo "=> using ${#MotionFiles[*]} Motion Files"

echo "SCRACTC: $SCRATCH"
echo "Afile:   $HOSTNAME"

for active in $ActiveFiles; do
  # get only the interating bit of the name
  # samve the prefix part for retreiving both .nii.gz and _time
  active=$(basename $active)
  active=${active%.nii.gz}
  export ActivePrefix="$active";
  active=${active#activation_}

  for motion in $MotionFiles; do

      export MotionFile=$motion
      motion=$(basename $motion)
      motion=${motion%motion}

      # set simID and directories
      export simID="${active}_${motion}"
      source simIDVars.sh

      # check if brain exists
      if [ -r ${simOutDir}/Brain_${simID}.nii.gz ]; then echo "skipping $simID. nii.gz exists";  continue; fi


      echo == Dispatching for $simID


      # what runs need to be made
      list=($(seq 1 $TotalCPUs))

      # modify runs list if logs files exist
      #   remove all finished if some logs do exist 
      #       via some unamed pipes -- sh alone won't cut it
      #
      #    note: log/1 was --procid=0 and produces $simID/possum_0
      [ -d $LogDir ] && list=($(diff                                   \
                              <(seq 1 $TotalCPUs)                      \
                              <(grep -l '^Possum finished' ${LogDir}/* |
                                 xargs basename                        |
                                 sort -n)                              | 
                                 perl -lne 'print $1 if m/< (\d+)/'    \
                              ))
      
      echo === have ${#list[@]} jobs to run

      # for every %16 items on the list, list the next 16
      # bash doesn't seem to care about going over array size
      for ((i=0; ${list[$i]} ; i+=$BlockedSize)); do 

         set -xe
         ARGS=$(echo ${list[@]:$i:$BlockedSize}| tr ' ' ':')
         qsub -v simID=$simID,MotionFile=$MotionFile,ActivePrefix=$ActivePrefix,ARGS=$ARGS $qsubScript 
         set +xe

         ##testing

         #export ARGS=$(echo ${list[@]:$i:$BlockedSize}| tr ' ' ':')
         #$qsubScript ${list[@]:$i:$BlockedSize}
         #echo queuer ${list[@]:$i:$BlockedSize}

      done

      echo waiter $simOutDir
      #./waiter.sh 

   done

done
