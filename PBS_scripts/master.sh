#!/usr/bin/env bash

# Master script, dispatches qsub in blocks of 16 (lower number gets priority in queueing?)
# 
#    use REALLYRUN and QSUBCOMMAND for finer control over what happens
#    REALLYRUN=1   will actually pass to qsub and possum will run instead of echo the command
#    QSUBCOMMAND   could be e.g. 'echo qsub'  'qsub -q debug'  or 'qsub -h' (for wallace)
#    JOBSIZE       override number of jobs sent to each queuer.sh instace (for wallace)
#
#
#    should execute in 'runlog' directory so output is orginized
#
#    EXAMPLE:
#
#    mkdir -p ~/Possum-02-2012/runlog/$(date +%F) && cd $_
#    REALLYRUN=1 ../../PBS_Scripts/master.sh
#
#
#    o environment is read from environment.sh
#    -- BatchedSize is defined by #PBS -l nproc= in queue.sh (probably always 16)
#    
#    o simID is unique to combination of 
#       - motionFile  --- deterimined by '*motion'
#       - activeFile  --- deterimined by 'act_**.nii.gz
#          o expects act_**_time to exist also
#
#    o possum logs to   scratch/sim/simID/logs/
#    o possum output to scratch/sim/simID/possum_
#    o combined outs to scratch/sim/simID/combined
#    o final nii as     scratch/sim/simID/Brain_${simID}.nii.gz
#
#    note: log/1 <=> --procid=0 <=> $simID/possum_0
#

# if we don't say to do anything special, use qsub
[ -z "$QSUBCOMMAND" ] && QSUBCOMMAND='qsub'

# would like to be running in a dir for collecting logs
[[ $(pwd) =~ runlog ]] || echo -e "\n** Think about running me in a runlog dir\n" 

case "$HOSTNAME" in 
    *blacklight*|*wallace*|*gromit*)
	SCRIPTDIR="$HOME/Possum-02-2012/PBS_scripts/" ;;
    *)
	SCRIPTDIR="ERROR" ;;
esac


# load TotalCPUs, blocked
source ${SCRIPTDIR}/environment.sh || exit


# e.g. activation_test_3vol.nii.gz
#      contriubtes  'test_3vol' to simID
ActiveFiles=($(ls $VARDIR/act*.nii.gz))

# e.g. zeromotion
#      contributes  'zero'      to simID
MotionFiles=($(ls $VARDIR/*motion))


# echo settings and give a chance to quit
# externally set options
# o e.g. export QSUBCOMMAND='echo qsub'
# o e.g. export QSUBCOMMAND='qsub -q debug -l ncpus=16 -l walltime=30:00'
# maybe use read instead of sleep?
echo -n "REALLYRUN:   "; [ "$REALLYRUN" == "1" ] && echo "YES" || echo "no"
echo    "QSUBCOMMAND: $QSUBCOMMAND"
echo    "Host:        $HOSTNAME"
echo    "SCRATCH:     $SCRATCH"
echo    "BlockedSize: $BlockedSize"
echo    "using"
echo    "=>           ${BrainFile}"
echo    "=>           ${MRFile}"
echo    "=>           ${RFFile}"
echo    "=> ${#ActiveFiles[*]} Active Files: ${ActiveFiles[*]}"
echo    "=> ${#MotionFiles[*]} Motion Files: ${MotionFiles[*]}"
echo 
echo
echo    "Intrupt to quit, anykey to proceed"
read
#echo    "   5 seconds to change your mind with interupt key"
#sleep 5

for active in ${ActiveFiles[@]}; do
  # get only the interating bit of the name
  # save the prefix part for retreiving both .nii.gz and _time
  active=$(basename $active)
  active=${active%.nii.gz}
  export ActivePrefix="$active";
  active=${active#act_}
  
  expectedVols=${active#*_}

  for motion in ${MotionFiles[@]}; do
  # e.g. 10761_1.5_150motion

      export MotionFile=$motion
      motion=$(basename ${motion%motion})


      if [ $expectedVols != ${motion##*_} ]; then
         echo "*** active has $expectedVols vols but motion has ${motion##*_}; skipping combination"
         continue
      fi

      # set simID and directories
      export simID="${active}_${motion}"
      source ${SCRIPTDIR}/simIDVars.sh

      # check if brain exists
      if [ -r ${simOutDir}/Brain_${simID}_abs.nii.gz ]; then echo "skipping Brain_${simID}_abs.nii.gz exists";  continue; fi


      # do this again to get the correct pulse file
      source ${SCRIPTDIR}/environment.sh || exit
      echo "==> Pulse:       ${PulseFile}"
      echo "==> Activation:  $active"
      echo "==> Motion:      $motion"
      echo "==> simlationID: $simID"
      echo "==> BlockedSize: $BlockedSize"
      echo


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
                                 xargs -n1 basename                    |
                                 sort -n)                              | 
                                 perl -lne 'print $1 if m/< (\d+)/'    \
                              ))
      
      echo -e "\n===>have ${#list[@]} jobs to run\n"

      # for every %16 items on the list, list the next 16
      # bash doesn't seem to care about going over array size
      for ((i=0; ${list[$i]} ; i+=$BlockedSize)); do 

         export ARGS=$(echo ${list[@]:$i:$BlockedSize}| tr ' ' ':')


         #only actually run if we've called with "REALLYRUN=1 ./master.sh"
         if [ "$REALLYRUN" == "1" ]; then 
         set -xe
            $QSUBCOMMAND -N "pos_$expectedVols-$i" -v REALLYRUN=1,simID=$simID,MotionFile=$MotionFile,ActivePrefix=$ActivePrefix,ARGS=$ARGS $qsubScript 
         set +xe
	 # otherwise run qsubscript 
	 # which assumes a mock run
	 # and only echos what it would do
         else
            echo $qsubScript $ARGS
         fi

      done


      echo "   NOT launching waiter.sh. Do it yourself"
      echo "   will need mot file and simID"
      echo "   MotionFile=$MotionFile"
      echo "   simID=$simID"
      echo "   $SCRIPTDIR/waiter.sh"
      echo "        out to $simOutDir"
      #./waiter.sh 

   done

done
