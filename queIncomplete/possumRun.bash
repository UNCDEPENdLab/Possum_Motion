#!/usr/bin/env sh

# possum settings


source /usr/share/modules/init/bash

njobs=256

inputDir=$HOME/Possum_Motion/defaults
motionDir=$inputDir/motion_parameters

function dircheck   { eval   dirt=\$$1;    [ -d "$dirt"   ] || mkdir -p $dirt; }


export LogDir="$SCRATCH/possum_rsfcmri/$simname/logs"
export SimOutDir="$SCRATCH/possum_rsfcmri/$simname/output"

#  check for log file, make if DNE
dircheck "LogDir"
dircheck "SimOutDir"

echo "SIMRUN:     $SIMRUN"
echo "SCRATCH:    $SCRATCH"
echo "OutputDir:  $SimOutDir"
echo "LogDir:     $LogDir"
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



## RUN FUNCTION 
# possum log numbers start at one, proc ids start at 0
function possumRun { 
   SIMRUN=$2
   cfgfile="$HOME/Possum_Motion/sim_cfg/$SIMRUN"
   expectedRuntime=$3

   if [ -n "$SIMRUN" -a -r $cfgfile]; then
       source $cfgfile
       simname=${SIMRUN}_$(date +%d%b%Y-%R)
   else
       echo "$1: $cfgfile DNE!!!! dieing"
       return
   fi
   LogFile="$LogDir/possumlog_$1"


   jobID_0=$(echo $1 - 1|bc)
   echo  "expected runtime: $expectedRuntime";
   echo -n "start: "; date
   echo possum                               \
           --nproc=$njobs \
           --procid=$jobID_0 \
           -o $SimOutDir/possum_${jobID_0} \
           -m $motion \
           -i $t1input \
           -x $mrPar \
           -f $slcprof \
           -p $pulse \
           --activ4D=$activ4D \
           --activt4D=$activTime \
           \> $LogFile 
   echo -n "finished: "; date
}

