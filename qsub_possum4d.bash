#!/usr/bin/env sh

###                 ###
### options for pbs ###
###                 ###

#PBS -l ncpus=256
#PBS -l walltime=18:00:00
#PBS -q batch
#PBS -j oe
#PBS -M hallquistmn@upmc.edu

source /usr/share/modules/init/bash

ncpus=256

SimOutDir=$SCRATCH/possum_rsfcmri/output
LogDir=$SCRATCH/possum_rsfcmri/logs
inputDir=$HOME/Possum_Motion/defaults

function dircheck   { eval   dirt=\$$1;    [ -d "$dirt"   ] || mkdir -p $dirt; }

#  check for log file, make if DNE
dircheck "LogDir"
dircheck "SimOutDir"

echo "SCRATCH: $SCRATCH"
echo "LogDir:  $LogDir"
echo "Host:    $HOSTNAME"

##############################
### Possum for each job id ###
##############################

FSLOUTPUTTYPE=NIFTI_GZ
PATH=$HOME/Possum_Motion/bin/linux:${PATH}
export PATH FSLOUTPUTTYPE

[ ! -f $inputDir/tr2_te30_pulse ] && bash $inputDir/default_pulse.bash

which ja && ja

for ((jobID=1; jobID <= ncpus ; jobID++)); do

   # job completion check/parse requires the log file be named only a number
   LogFile="$LogDir/possumlog_$(printf "%04d" ${jobID})"

   let "jobID_0 = jobID - 1"  #possum is zero based, the log structure is not!

   # run or print out what we would run
   if [ "$REALLYRUN" == "1" ]; then

      set -x
      possum                               \
          --nproc=$ncpus                   \
          --procid=$jobID_0                \
          -o $SimOutDir/possum_${jobID_0}    \
          -m $inputDir/motion_parameters/zeromotion          \
          -i $inputDir/possum_10895_fast.nii.gz        \
          -x $inputDir/MRpar_3T            \
          -f $inputDir/slcprof             \
          -p $inputDir/tr2_te30_pulse       \
          --activ4D=$inputDir/10895_POSSUM4D_bb264_roiAvg_fullFreq.nii.gz \
          --activt4D=$inputDir/activt_150 \
            > $LogFile &
      set +x

      #[[ $HOSTNAME =~ blacklight ]] && ja -chlst > $QueLogDir/${simID}_${jobID}.job.log
      #which ja &&  ja -chlst > $QueLogDir/${simID}_${jobID}.job.log

      #-c command report
      #-h Kilobytes of largest memory usage
      #-l "additional info"
      #-s summary report
      #-t terminates accounting
   else
      ## testing: just say we got here
      echo 
      echo possum                          \
          --nproc=$ncpus                   \
          --procid=$jobID_0                \
          -o $SimOutDir/possum_${jobID_0}    \
          -m $inputDir/motion_parameters/zeromotion          \
          -i $inputDir/possum_10895_fast.nii.gz        \
          -x $inputDir/MRpar_3T            \
          -f $inputDir/slcprof             \
          -p $inputDir/tr2_te30_pulse       \
          --activ4D=$inputDir/10895_POSSUM4D_bb264_roiAvg_fullFreq.nii.gz \
          --activt4D=$inputDir/activt_150 \
            ">" $LogFile
      echo
   fi


done

echo "forked jobs!"
date

time wait 

echo "finished!"
date


ja -chlst
