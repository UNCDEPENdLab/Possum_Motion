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
  
  #what should motionSID be?

  motionOut="${VARDIR}/${MotionPrefix}motion"

  if [ ! -r $motionOut ]; then
     
      # motion file not in the right format
      if [[ $motionBaseFile =~ dfile ]]; then
         dfile=$motionBaseFile
         empDir="defaults/empiricalMotion"

         #update motion base
         motionBaseFile=$empDir/${motionSID}motion
         $empDir/convertDfileToPossum.R $dfile $motionBaseFile

         echo "converted motion to $motionBaseFile"
      fi
      

     # start with motion at 0
     # use actual volnum
     # increment by actual TR not simulation TR (TR_pulse)
     # extend last motion until end if file is shorter than num TRs (e.g. zeromotion)

     echo "using $volnum of volumes inc. by $TR for motion of $motionSID"
     # MOTION STARTS AFTER DUMMY
     perl -slane 'BEGIN{$n=0;@l=(); 
                  # motion starts at 0+offset, goes to volnum-1 in increments of TR (1.5)
                  sub pline{ print join("  ", ((shift) - 1)*$ENV{TR}+ 4*$ENV{TR_pulse} , @l )  }} 
                  @l=@F[1...$#F]; 
                  pline($.) if $. <= $ENV{volnum}; 
                  $n=$.; 
                  END{
                     pline($n) while(++$n<=$ENV{volnum})
                  }' $motionBaseFile > $motionOut

      echo "made: $motionOut"
   fi

   # if either activation file is missing, make both
   if [ ! -r $ActivationFile ] || [ ! -r $ActivationTimeFile ]; then

     
      
      # activation map w/vols from 0-199 needs to be 0-(volnum-1)
      # start activation time offset by 4 TR_pulse
      # print time for each step of corVolNum as steps of TR 
      # *** Should this be -5 instead of -1 ???? -- the first 4 are junk
      perl -le "print ${TR}*\$_ + 4*${TR_pulse} for (0..$volnum-1)" >  $ActivationTimeFile
    
      echo "made: $ActivationTimeFile"

      #200 not corrected
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

      # actual experment is 1.5*200
      # but pulse has to be created with TR=2.05 so numvols must be corrected

      # realTR*realVolnum         = pulseTR*(correctedVol - 4 junk)
      # realTR*realVolnum/pulseTR = (correctedVol - 4 junk)
      # 1.5*15/2.05  + 4 = 14.975 => 15
      # 1.5*154/2.05 + 4 =        => 117
      # 1.5*200/2.05 + 4 = 150.3  => 150
      # $TR*$volnum/$TR_pulse + 4
      corVolNum=$(echo "$TR*$volnum/$TR_pulse + 4 + .5" |bc -l); 
      corVolNum=${corVolNum%.*} # + .5 %.* == round
      echo "using $corVolNum of volumes with ${TR_pulse} for pulse"

      # build pulse
      pulse -i ${BrainFile} -o $PulseOut  --te=0.029 --tr=${TR_pulse} \
       --trslc=0.066 --nx=58 --ny=58 --dx=0.0032 --dy=0.0032 \
       --maxG=0.04 --riset=0.0002 --bw=156252 \
       --numvol=$corVolNum --numslc=31 --slcthk=0.0039 --zstart=0.038 \
       --seq=epi --slcdir=z+ --readdir=x+ \
       --phasedir=y+ --gap=0.0 -v --cover=100 --angle=85 > logs/pulseSetup 2>&1

      echo "made: $PulseOut"
  fi
}

#set 
export motionBaseFile="defaults/empiricalMotion/10761.wU.dfile"

export         volnum=200

export activationBaseFile=defaults/10653_POSSUM4D_bb244_fullFreq_RPI.nii.gz

export      SCRIPTDIR="$HOME/Possum-02-2012"

### PAST
#zero motion filse
#export motionBaseFile=defaults/zeromotion
# subject 10871
# created from dfile via defaults/empiricalMotion/convertDfileToPossum.R
#export motionBaseFile=defaults/empiricalMotion/10871motion




####
# below is not likely to change
####

#export MotionPrefix
case $motionBaseFile in
*.dfile)
    # maybe want to keep e.g. .wU instead of clear 
    # everything after .
    motionSID="$(basename ${motionBaseFile%%.*} )" ;;
 *motion)
    motionSID="$(basename ${motionBaseFile} motion)";;
 *)
    echo "ERROR: What kind of motionBaseFile is $motionBaseFile?"
    exit 1;;
esac
  

export           TR=1.5   #should be experimental value
export     TR_pulse=2.05  #changing me requires adjusting pulse params

export MotionPrefix="${motionSID}_${TR}_${volnum}"
export ActivePrefix="act${TR}_${volnum}"

## load BrainFile ActivationFile ActivationTimeFile
source ${SCRIPTDIR}/PBS_scripts/environment.sh

generateNumVol 2>&1 | tee -a logs/makefiles.log





