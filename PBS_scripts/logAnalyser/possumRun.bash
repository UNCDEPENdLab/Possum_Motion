#!/usr/bin/env sh

# possum settings

source /usr/share/modules/init/bash

ncpus=16
njobs=256

inputDir=$HOME/Possum_Motion/defaults
motionDir=$inputDir/motion_parameters

function dircheck   { eval   dirt=\$$1;    [ -d "$dirt"   ] || mkdir -p $dirt; }

if [ -n "$SIMRUN" ]; then
    source "$HOME/Possum_Motion/sim_cfg/$SIMRUN"
    simname=${SIMRUN}_$(date +%d%b%Y-%R)
else
    simname=simout_$(date +%d%b%Y-%R) #default to runtime/date
fi

LogDir="$SCRATCH/possum_rsfcmri/$simname/logs"
SimOutDir="$SCRATCH/possum_rsfcmri/$simname/output"

#  check for log file, make if DNE
dircheck "LogDir"
dircheck "SimOutDir"

echo "SIMRUN:     $SIMRUN"
echo "SCRATCH:    $SCRATCH"
echo "OutputDir:  $SimOutDir"
echo "LogDir:     $LogDir"
echo "Host:       $HOSTNAME"

#defaults, if not set in the sim cfg
[ -z "$motion" ]    &&    motion="$motionDir/zeromotion"
[ -z "$t1input" ]   &&   t1input="$inputDir/possum_10895_fast.nii.gz"
[ -z "$activ4D" ]   &&   activ4D="$inputDir/10895_POSSUM4D_bb264_roiAvg_fullFreq.nii.gz"
[ -z "$activTime" ] && activTime="$inputDir/activt_150"
[ -z "$mrPar" ]     &&     mrPar="$inputDir/MRpar_3T"
[ -z "$slcprof" ]   &&   slcprof="$inputDir/slcprof"
[ -z "$pulse" ]     &&     pulse="$inputDir/tr2_te30_pulse"

##############################
### Possum for each job id ###
##############################

FSLOUTPUTTYPE=NIFTI_GZ
PATH=$HOME/Possum_Motion/bin/linux:${PATH}
export PATH FSLOUTPUTTYPE

[ ! -f $inputDir/tr2_te30_pulse ] && bash $inputDir/default_pulse.bash

which ja && ja



## RUN FUNCTION 

function possumRun { 
   runum=$1
   echo -n "start: "; date
   echo possum                               \
          --nproc=$TotalCPUs               \
          --procid=$jobID                  \
          -o $SimOutDir/possum_${runum}    \
          -m ${MotionFile}                 \
          -i ${BrainFile}                  \
          -x ${MRFile}                     \
          -f ${RFFile}                     \
          -p ${PulseFile}                  \
          --activ4D=${ActivationFile}      \
          --activt4D=${ActivationTimeFile} \
          #  > $LogFile 
   echo -n "finished: "; date
}

