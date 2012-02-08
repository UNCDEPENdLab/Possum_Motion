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
  echo -e "	 $motionBaseFile "
  echo -e "	 $activationBaseFile "
  


  # each line corresponds to one volume step in time
  # replace TR intervals with new ones
  

  MotionOut="${VARDIR}/${MotionPrefix}motion"
  if [ ! -r $MotionOut ]; then
     # start with motion at 0
     # extend last motion until end if file is shorter than num TRs (e.g. zeromotion)
     perl -slane 'BEGIN{$n=0;@l=(); 
                  sub pline{ print join("  ",((shift) - 1)*$ENV{TR},@l)  }} 
                  @l=@F[1...$#F]; 
                   pline($.) if $. < $ENV{volnum}; 
                  $n=$.; 
                  END{
                     pline($n) while(++$n<=$ENV{volnum})
                  }' $motionBaseFile > $MotionOut

      echo "made: $MotionOut"
   fi

   # if either activation file is missing, make both
   if [ ! -r $ActivationFile ] || [ ! -r $ActivationTimeFile ]; then
      #head  -n${volnum} $activationTimeFile > ${rundir}/activation_time  
      #Build timecourse
      # need better uper bound
      perl -le "print ${TR}*\$_ + ${TR_pulse}*4 for (0..$volnum-1)" >  $ActivationTimeFile
    
      echo "made: $ActivationTimeFile"

     
      # activation map w/vols from 0-199 needs to be 0-(volnum-1)
      # should do more to set length 11*2.05 == 15*1.5     -- ish
      3dTcat \
       ${activationBaseFile}[0..$((($volnum-1)))] \
       -prefix $ActivationFile
     
      # and make TR what we want
      pushd  $VARDIR
      3drefit -TR $TR $ActivationFile 
      popd

      echo "made: $ActivationFile" 
   fi

  PulseOut="${BASEDIR}/pulse_${volnum}"
  if [ ! -r $PulseOut ]; then
      # build pulse
      pulse -i ${BrainFile} -o $PulseOut  --te=0.029 --tr=2.05 \
       --trslc=0.066 --nx=58 --ny=58 --dx=0.0032 --dy=0.0032 \
       --maxG=0.04 --riset=0.0002 --bw=156252 \
       --numvol=$volnum --numslc=31 --slcthk=0.0039 --zstart=0.038 \
       --seq=epi --slcdir=z+ --readdir=x+ \
       --phasedir=y+ --gap=0.0 -v --cover=100 --angle=85 > logs/pulseSetup 2>&1

      echo "made: $PulseOut"
  fi
}

#set 
export       TR=1.5
export TR_pulse=2.05
export   volnum=15

#zero motion filse
#export motionBaseFile=defaults/zeromotion

# subject 10871
# created from dfile via defaults/empiricalMotion/convertDfileToPossum.R
export motionBaseFile=defaults/empiricalMotion/10871motion

export activationBaseFile=defaults/10653_POSSUM4D_bb244_fullFreq_RPI.nii.gz

export ActivePrefix="act${TR}_${volnum}"
export MotionPrefix="$(basename $motionBaseFile motion)_${TR}_${volnum}"

## load BrainFile ActivationFile activationTimeFile
source $HOME/Possum-02-2012/PBS_scripts/environment.sh


generateNumVol 2>&1 | tee -a logs/makefiles.log





