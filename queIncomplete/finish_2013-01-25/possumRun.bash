#!/usr/bin/env sh

# possum settings


source /usr/share/modules/init/bash

njobs=256

inputDir=$HOME/Possum_Motion/defaults
motionDir=$inputDir/motion_parameters

function dircheck   { eval   dirt=\$$1;    [ -d "$dirt"   ] || mkdir -p $dirt; }



echo "SCRATCH:    $SCRATCH"
echo "Host:       $HOSTNAME"

# assume these are all ready from sim_cfg .. which is loaded per possum process (rather than here, per job)
#defaults, if not set in the sim cfg
#[ -z "$motion" ]    &&    motion="$motionDir/zeromotion"
#[ -z "$t1input" ]   &&   t1input="$inputDir/possum_10895_fast.nii.gz"
#[ -z "$activ4D" ]   &&   activ4D="$inputDir/10895_POSSUM4D_bb264_roiAvg_fullFreq.nii.gz"
#[ -z "$activTime" ] && activTime="$inputDir/activt_150"
#[ -z "$mrPar" ]     &&     mrPar="$inputDir/MRpar_3T"
#[ -z "$slcprof" ]   &&   slcprof="$inputDir/slcprof"
#[ -z "$pulse" ]     &&     pulse="$inputDir/tr2_te30_pulse"
#[ ! -f $inputDir/tr2_te30_pulse ] && bash $inputDir/default_pulse.bash

##############################
### Possum for each job id ###
##############################

FSLOUTPUTTYPE=NIFTI_GZ
PATH=$HOME/Possum_Motion/bin/linux:${PATH}
export PATH FSLOUTPUTTYPE


which ja && ja

cleanup () {
    echo "Exiting script due to sigint/sigterm/exit"
    ja -chlst    
    exit 1
}
trap cleanup SIGINT SIGTERM


## RUN FUNCTION 
# possum log numbers start at one, proc ids start at 0
function possumRun { 
   jobID=$1
   SIMRUN=$2
   cfgfile="$HOME/Possum_Motion/sim_cfg/$SIMRUN"
   expectedRuntime=$3

   if [ -z "$jobID" ]; then
       echo "no jobID (first argument); quiting"
   fi

   if [ -n "$SIMRUN" -a -r "$cfgfile" ]; then
       source $cfgfile
       # simname should wild card complete
       # to get the the date
       simname=$(ls -1d $SCRATCH/possum_rsfcmri/${SIMRUN}_* |sed 1q)

       # check we completed the above
       if [ ! -d "$simname" ]; then
         echo "cannot find simname's date!: $simname"
         return
       fi

       # dont want dirname in the simulation name (we just wanted the date)
       simname=$(basename $simname /)
   else
       echo "$jobID: '$SIMRUN' undefed or '$cfgfile' DNE!!!! dieing"
       return
   fi

   LogDir="$SCRATCH/possum_rsfcmri/$simname/logs"
   SimOutDir="$SCRATCH/possum_rsfcmri/$simname/output"

   #  check for log file, make if DNE
   dircheck "LogDir"
   dircheck "SimOutDir"

   LogFile="$LogDir/possumlog_$jobID"
   RunningLock=$SimOutDir/running-$jobID

   # move old log file if it exists (it should!)
   [ -r $LogFile ] && mv $LogFile ${LogFile}.mvdOn$(date +%F_%R)

   echo "OutputDir:  $SimOutDir"
   echo "LogDir:     $LogDir"
   echo "SIMRUN:     $SIMRUN"

   function cleanup {
    if [ -r "$RunningLock" ]; then
      rm $RunningLock;
    else
      echo "$RunningLock DNE!!?";
    fi
   }
   # remove lock file if killed
   function cleanupresume {
    echo "$jobID did not finish! Caught SIGINT/TERM"
    cleanup
   }
   trap cleanupresume SIGINT SIGTERM

   jobID_0=$(echo $jobID - 1|bc)
   possumCmd="possum \\
           --nproc=$njobs \\
           --procid=$jobID_0 \\
           -o $SimOutDir/possum_${jobID_0} \\
           -m $motion \\
           -i $t1input \\
           -x $mrPar \\
           -f $slcprof \\
           -p $pulse \\
           --activ4D=$activ4D \\
           --activt4D=$activTime"

   if [ -r $RunningLock ]; then
    echo "$RunningLock exists! not running"
    return
   fi

   # touch run log
   date +%F_%R > $RunningLock

   echo "Lock on $RunningLock"               | tee $LogFile
   echo "Expected runtime: $expectedRuntime" | tee -a $LogFile
   echo "Start time: $(date +%d%b%Y-%R)"     | tee -a $LogFile
   echo "Start time epoch(s): $(date +%s)"   | tee -a $LogFile
   echo -e "${possumCmd}\n\n"                | tee -a $LogFile
   #run the CMD by echoing within a command substitution
   #need tr to replace backslashes with a space to avoid escaping issues
    #$( echo "$possumCmd" | tr "\\\\" " " ) >> $LogFile 
   echo "sleeping instead of running possum!" && sleep 100
   echo "Finished:  $(date +%F_%R)"         | tee -a $LogFile
   cleanup
}

