#!/bin/bash
#set -ex -- we kill processes, stopping because of that would be bad
set -e

# Possum Memory Usage
#  as depdent on 
#   - num. volumes 
#   - num. processors
#
# output directed to log/byvol*usage




##############
# generate truncated files for different number of volumes
#   o trunc. motion, activation nii to numvol (numvols <200)
#   o translate motion, activation to TR
#   o generate new activation time course
#   o generate new pulse
#   - needs defined:
#     TR, volnum, rundir, motionFile, and activationBaseFile
##########
function generateNumVol {
  
  echo ==== constructing $TR $volnum ====
  


  # each line corresponds to one volume step in time
  # replace TR intervals with new ones
  


  # start with motion at 0
  # extend last motion until end if file is shorter than num TRs (e.g. zeromotion)
  perl -slane 'BEGIN{$n=0;@l=(); 
               sub pline{ print join("  ",((shift) - 1)*$ENV{TR},@l)  }} 
               @l=@F[1...$#F]; 
                pline($.) if $. < $ENV{volnum}; 
               $n=$.; 
               END{
                  pline($n) while(++$n<=$ENV{volnum})
               }' $motionBaseFile > ${VARDIR}/${MotionPrefix}motion

   echo "made: ${VARDIR}/${MotionPrefix}motion"

   #head  -n${volnum} $activationTimeFile > ${rundir}/activation_time  
   #Build timecourse
   perl -le "print $TR*\$_ + $TR*4 for (0..$volnum-1)" >  $ActivationTimeFile
 
   echo "made: $ActivationTimeFile"

  
   # activation map w/vols from 0-199 needs to be 0-(volnum-1)
   3dTcat \
    ${activationBaseFile}[0..$((($volnum-1)))] \
    -prefix $ActivationFile
  
   # and make TR what we want
   3drefit -TR $TR $ActivationFile 

   echo "made: $ActivationFile" 

   # build pulse
   pulse -i ${Brain} -o ${BASEDIR}/pulse_${volnum} --te=0.029 --tr=2.05 \
    --trslc=0.066 --nx=58 --ny=58 --dx=0.0032 --dy=0.0032 \
    --maxG=0.04 --riset=0.0002 --bw=156252 \
    --numvol=$volnum --numslc=31 --slcthk=0.0039 --zstart=0.038 \
    --seq=epi --slcdir=z+ --readdir=x+ \
    --phasedir=y+ --gap=0.0 -v --cover=100 --angle=85 > logs/pulseSetup 2>&1

   echo "made: ${BASEDIR}/pulse_${volnum}"
}

#set 
export       TR=1.5
export TR_pulse=2.05
export   volnum=15

export motionBaseFile=defaults/zeromotion
export activationBaseFile=defaults/10653_POSSUM4D_bb244_fullFreq_RPI.nii.gz

export ActivePrefix="act${TR}_${volnum}"
export MotionPrefix="zero_${TR}_${volnum}"

## load MotionFile and AcitvationFile activationTimeFile
source $HOME/Possum-02-2012/PBS_scripts/environment.sh


generateNumVol 2>&1 | tee -a logs/makefiles.log





