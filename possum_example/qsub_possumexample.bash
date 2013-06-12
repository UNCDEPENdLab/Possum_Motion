#!/usr/bin/env sh

###                 ###
### options for pbs ###
###                 ###

#PBS -l ncpus=32
#PBS -l walltime=22:00:00
#PBS -q batch
#PBS -j oe
#PBS -M hallquistmn@upmc.edu

source /usr/share/modules/init/bash

ncpus=32
inputDir=$HOME/Possum_Motion/possum_example

[ -z "$run4D" ]      && run4D=0 #default to 3d simulation
[ -z "$TEST" ]      && TEST=1  #default to a test run
[ -z "$motfile" ]    && motFile=$inputDir/zeromotion


if [ $run4D -eq 0 ]; then
    SimOutDir=$SCRATCH/possum_example/output
    LogDir=$SCRATCH/possum_example/logs
else 
    SimOutDir=$SCRATCH/possum_example_4d/output
    LogDir=$SCRATCH/possum_example_4d/logs
fi

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

echo "Possum binary: $(which possum)"

[ ! -r $inputDir/example_pulse ] && source $inputDir/generate_example_pulse.bash

which ja && ja

IFS=:
for ((jobID=1; jobID <= ncpus ; jobID++)); do

   # job completion check/parse requires the log file be named only a number
    JobLog="$LogDir/possumlog_$(printf "%04d" ${jobID})"

    let "jobID_0 = jobID - 1"  #possum is zero based, the log structure is not!

    if [ $run4D -eq 1 ]; then
	possumCmd="possum \\
          --nproc=$ncpus \\
          --procid=$jobID_0 \\
          -o $SimOutDir/possum_${jobID_0} \\
          -m $motFile \\
          -i $inputDir/brain.nii.gz \\
          -x $inputDir/MRpar_3T \\
          -f $inputDir/slcprof \\
          -p $inputDir/example_pulse \\
          --activ4D=$inputDir/example_activ4D.nii.gz \\
          --activt4D=$inputDir/example_activ4Dtc.txt"
    else
	possumCmd="possum \\
          --nproc=$ncpus                   \\
          --procid=$jobID_0                \\
          -o $SimOutDir/possum_${jobID_0}  \\
          -m $motFile          \\
          -i $inputDir/brain.nii.gz        \\
          -x $inputDir/MRpar_3T            \\
          -f $inputDir/slcprof             \\
          -p $inputDir/example_pulse       \\
          --activ=$inputDir/activation3D.nii.gz     \\
          --activt=$inputDir/activation3Dtimecourse"
    fi

    echo "Start time: $(date +%d%b%Y-%R)" > $JobLog
    echo "Start time epoch(s): $(date +%s)" >> $JobLog
    echo -e "${possumCmd}\n\n" >> $JobLog
  
    echo "$possumCmd"

    if [ "$TEST" -ne "1" ]; then
        # run the CMD by echoing within a command substitution
        # need tr to replace backslashes with a space to avoid escaping issues
	#$( echo "$possumCmd" | tr "\\\\" " " ) >> $JobLog
	bash -c "$possumCmd" >> $JobLog & #for some reason, sometimes the echo above was trying to run the whole thing as a quoted command
	pid=$!
	
	sleep 1 #give the loop a second to rest when forking a bunch of jobs at the beginning of the run 
    fi

done

echo "forked jobs!"
date

time wait 

echo "finished!"
date


ja -chlst
