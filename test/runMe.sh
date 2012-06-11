#!/usr/bin/env bash

#
# builds pulse and runs possum
# processes nifiti
# compare activation of simulated and near zero-motion subject 10653
# !!!! PROBLEM: actual activation is not corrilated with simulation 
#
#
# inputs/
# 
# act1.5_15.nii.gz          activation of subj 10653,   15 volumes (actual TR=1.5), createTemplate.sh
# act1.5_15_time            time course for activation, 15 volumes (actual TR=1.5)
# zero_1.5_15motion         $FSLDIR/data/possum/zeromotion truncated to 1.5*15 seconds, starts 4*2.05 seconds in
# possum_10653_fast.nii.gz  subject 10653 mprage segmented into 3 sub bricks

### check the environment
[ ! -r $FSLDIR/data/possum/MRpar_3T ] && echo "FSLDIR doesn't lead to expected possum files" && exit




#### Setup variables

export   TR_record=1.5   # should be recorded (experimental) value
export    TR_pulse=2.05  # changing me requires adjusting pulse params
export goodSimVols=11    # number of good volumes want to extract from simulation
export     junkVol=4     # number of volumes to trash

# total number of volumes to simulate
export possumVol=$((( $junkVol + $goodSimVols ))) # == 15

# how many volumes of activation information do we need for the volumes we will extract from the simulation
# = TR of simulation * number of volumes wanted    / TR of actual activation
export volFromSubj=$(printf '%.0f' $(echo "$goodSimVols*$TR_pulse/$TR_record"|bc -l))  
#          = 11*2.05/1.5 = 15.03 => 15

# activation starts one TR (recorded) after the junk padding volumes (TR_pulse*junkVols)
export subjActStartTime=$(echo ${junkVol}*${TR_pulse}+${TR_record}|bc -l)

cat <<HEREDOC
Building simulation input for:
  TR_record  $TR_record
  TR_pulse   $TR_pulse
  with $possumVol total simulated volumes (discarding first $junkVol)
  last $goodSimVols simulated using first $volFromSubj subj vols
  activation and motion start at $subjActStartTime

HEREDOC





### Build inputs

#### Build pulse
[ -r inputs/pulse_15 ] || \
 pulse -i fromSubj/possum_10653_fast.nii.gz                          \
       -o inputs/pulse_15  --te=0.029 --tr=$TR_pulse                 \
      --trslc=0.066 --nx=58 --ny=58 --dx=0.0032 --dy=0.0032          \
      --maxG=0.04 --riset=0.0002 --bw=156252                         \
      --numvol=$possumVol --numslc=31 --slcthk=0.0039 --zstart=0.038 \
      --seq=epi --slcdir=z+ --readdir=x+                             \
      --phasedir=y+ --gap=0.0 -v --cover=100 --angle=85              \
    2>&1 | tee logs/pulseSetup 


#### Create Motion
# use another motion file and just put new times (ofset by junkvols * pulse TR and incremented by experiment TR) in place of old times
# if more lines required than provided in file, repeat last line
perl -slane 'BEGIN{$n=0;@l=(); 
            # motion starts at 0+offset, goes to volFromSubj in increments of TR (1.5)
            sub pline{ print join("  ", ((shift) - 1)*$ENV{TR_record}+ $ENV{subjActStartTime} , @l )  }} 
            @l=@F[1...$#F]; 
            pline($.) if $. <= $ENV{volFromSubj}; 
            $n=$.; 
            END{
               pline($n) while(++$n<=$ENV{volFromSubj})
            }' $FSLDIR/data/possum/zeromotion > inputs/zero_1.5_15motion


#### Activation

##### Time
# start activation time offset by junkvolNum * TR_pulse
# *** maybe -5 instead of -1 ? -- the first 4 are junk
perl -le "print ${TR_record}*\$_ + ${subjActStartTime} for (0..$volFromSubj-1)" >  inputs/act1.5_15_time 

##### Truncate real activation, not concerned with junk vols
# nii file input comes from original/Scripts/createTemplate.bash
[ -r inputs/act1.5_15.nii.gz ] || \
 3dTcat -overwrite -prefix inputs/act1.5_15.nii.gz fromSubj/10653_POSSUM4D_bb244_fullFreq_RPI.nii.gz[0..$((($volFromSubj-1)))] 
# should refit to TR_pulse? not TR, doesn't matter anyway?
#3drefit -TR $TR_record inputs/act1.5_15.nii.gz 
 





#### Run possum
set -xe


# PBS_scripts/master.sh:  set MotionFile
# PBS_scripts/environment.sh: set All other inputs
# PBS_scripts/queuer.sh: execute possum
cpus=10
for jobID in $( seq 0 $((($cpus-1))) ); do

 # run possum if haven't
[ -r sim/possum_${jobID}  ] || \
 possum                                  \
  --nproc=$cpus                          \
  --procid=$jobID                        \
  -o sim/possum_${jobID}                 \
  -m inputs/zero_1.5_15motion            \
  -i fromSubj//possum_10653_fast.nii.gz  \
  -x $FSLDIR/data/possum/MRpar_3T        \
  -f $FSLDIR/data/possum/slcprof         \
  -p inputs/pulse_15                     \
  --activ4D=inputs/act1.5_15.nii.gz      \
  --activt4D=inputs/act1.5_15_time  2>&1 | tee logs/possum_${jobID}.log &

done # with each possum job

echo "launched all possums, waiting to finish"
#while [ -n "$(jobs)" ];do echo "sleeping 30"; sleep 30m; done
while pgrep possum;do echo "sleeping 30"; sleep 30m; done

##### combine all the runs

[ -r sim/combined  ] || \
 possum_sum -i sim/possum_ -o sim/combined -n $cpus -v 2>&1 |
  tee logs/possum_sum.log

##### put into nifiti
[ -r sim/simBrain_abs.nii.gz ] || \
 signal2image -i sim/combined -a --homo -p inputs/pulse_15 -o sim/simBrain |
  tee logs/signal2image.log

## copy nifti to preproc, don't copy, truncate
#3dcopy sim/simBrain_abs.nii.gz preproc/simBrain.nii.gz

### remove junk volumes  (bandpass doesn't like having too few volumes, have to use 3dDetrend for small volume test run)
3dTcat -overwrite -prefix preproc/simBrain_goodVols.nii.gz sim/simBrain_abs.nii.gz[$junkVol..$] 

##### preprocess nifiti (skull strip, bandpass)
cd preproc
../restPreproc_possum.bash -4d simBrain_goodVols.nii.gz
cd -


#### check corrilation
# need R and a few R packages (see readme)
Rscript Check_ActivationCorrs_11Vol.R
