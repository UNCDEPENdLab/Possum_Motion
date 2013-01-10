#!/usr/bin/env sh

###                 ###
### options for pbs ###
###                 ###

#PBS -l ncpus=32
#PBS -l walltime=3:30:00
#PBS -q batch
#PBS -j oe
#PBS -M hallquistmn@upmc.edu

source /usr/share/modules/init/bash

ncpus=32

SimOutDir=$SCRATCH/possum_example/output
LogDir=$SCRATCH/possum_example/logs
inputDir=$HOME/Possum_Motion/possum_example

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

[ ! -f $inputDir/example_pulse ] && source $inputDir/generate_example_pulse.bash

which ja && ja

IFS=:
for ((jobID=1; jobID <= ncpus ; jobID++)); do

   # job completion check/parse requires the log file be named only a number
   LogFile="$LogDir/${jobID}"

   let "jobID_0 = jobID - 1"  #possum is zero based, the log structure is not!

   # run or print out what we would run
   if [ "$REALLYRUN" == "1" ]; then

      set -x
      possum                               \
          --nproc=$ncpus                   \
          --procid=$jobID_0                \
          -o $SimOutDir/possum_${jobID}    \
          -m $inputDir/zeromotion          \
          -i $inputDir/brain.nii.gz        \
          -x $inputDir/MRpar_3T            \
          -f $inputDir/slcprof             \
          -p $inputDir/example_pulse       \
          --activ=$inputDir/activation3D.nii.gz     \
          --activt=$inputDir/activation3Dtimecourse \
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
          -o $SimOutDir/possum_${jobID}    \
          -m $inputDir/zeromotion          \
          -i $inputDir/brain.nii.gz        \
          -x $inputDir/MRpar_3T            \
          -f $inputDir/slcprof             \
          -p $inputDir/example_pulse       \
          --activ=$inputDir/activation3D.nii.gz     \
          --activt=$inputDir/activation3Dtimecourse \
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
