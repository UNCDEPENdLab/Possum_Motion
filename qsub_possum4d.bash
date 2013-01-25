#!/usr/bin/env sh

###                 ###
### options for pbs ###
###                 ###

#PBS -l ncpus=112
#PBS -l walltime=46:00:00
#PBS -q batch
#PBS -j oe
#PBS -M hallquistmn@upmc.edu

source /usr/share/modules/init/bash

ncpus=112
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
[ -z "$motion" ] && motion="$motionDir/zeromotion"
[ -z "$t1input" ] && t1input="$inputDir/possum_10895_fast.nii.gz"
[ -z "$activ4D" ] && activ4D="$inputDir/10895_POSSUM4D_bb264_roiAvg_fullFreq.nii.gz"
[ -z "$activTime" ] && activTime="$inputDir/activt_150"
[ -z "$mrPar" ] && mrPar="$inputDir/MRpar_3T"
[ -z "$slcprof" ] && slcprof="$inputDir/slcprof"
[ -z "$pulse" ] && pulse="$inputDir/tr2_te30_pulse"

##############################
### Possum for each job id ###
##############################

FSLOUTPUTTYPE=NIFTI_GZ
PATH=$HOME/Possum_Motion/bin/linux:${PATH}
export PATH FSLOUTPUTTYPE

[ ! -f $inputDir/tr2_te30_pulse ] && bash $inputDir/default_pulse.bash

which ja && ja

cleanup () {
    echo "Exiting script due to sigint/sigterm/exit"
    ja -chlst    
    exit 0 #make sure the script exits and doesn't run another person
}
trap cleanup SIGINT SIGTERM

for ((jobID=1; jobID <= njobs ; jobID++)); do

   # job completion check/parse requires the log file be named only a number
   LogFile="$LogDir/possumlog_$(printf "%04d" ${jobID})"

   let "jobID_0 = jobID - 1"  #possum is zero based, the log structure is not!

   # run or print out what we would run

   if [ "$TEST" == "1" ]; then
      ## testing: just say we got here
      echo 
      echo possum \
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
            ">" $LogFile
      echo

   else

        #wait here until number of running jobs is <= ncpus

       joblist=($(jobs -p))
       curjoblist=${joblist[@]}
       echo 
       echo "---------" 
       echo "Jobs running: ${#joblist[*]}"
       echo "CPU limit: ${ncpus}"
       echo
       if [ ! -z ${joblist} ]; then
           ps -o pid,args -p ${joblist[@]}
       fi
       echo "---------"

       while (( ${#joblist[*]} >= ${ncpus} ))
       do
           sleep 30
           joblist=($(jobs -p))

           numrunning=${#joblist[*]}
           #echo "Number of processes running: ${numrunning}"

           if [[ "${joblist[@]}" != "${curjoblist[@]}" ]]; then
	       echo 
	       echo "---------"
	       echo "Jobs running: ${#joblist[*]}"
	       echo "CPU limit: ${ncpus}"
	       echo             
               if [ ! -z ${joblist} ]; then
                   ps -o pid,args -p ${joblist[@]}
               fi
	       echo "---------" 

               curjoblist=${joblist[@]}
           fi
       done
      
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

       echo "Start time: $(date +%d%b%Y-%R)" > $LogFile
       echo -e "${possumCmd}\n\n" >> $LogFile
       set -x
       #run the CMD by echoing within a command substitution
       #need tr to replace backslashes with a space to avoid escaping issues
       $( echo "$possumCmd" | tr "\\\\" " " ) >> $LogFile &
       set +x
       pid=$!

       sleep 1 #give the loop a second to rest when forking a bunch of jobs at the beginning of the run 
       
      #[[ $HOSTNAME =~ blacklight ]] && ja -chlst > $QueLogDir/${simID}_${jobID}.job.log
      #which ja &&  ja -chlst > $QueLogDir/${simID}_${jobID}.job.log
       
      #-c command report
      #-h Kilobytes of largest memory usage
      #-l "additional info"
      #-s summary report
      #-t terminates accounting
   fi
   
   
done

echo "forked jobs!"
date

time wait 

echo "finished!"
date

ja -chlst



#Older idea to separate out zero-voxel runs. Now using a jobs watcher to determine when to fork jobs.

# [ -z "$zeroVoxProc" ] && zeroVoxProc=( $( seq 0 23 ) $(seq 169 255) )

# #determine which are zero vox jobs and which will require substantial run-time
# allProcIDs=$( seq 0 $(($njobs - 1)) )

# #comm depends on alpha-based sort and will not give correct output for numeric sort
# echo ${zeroVoxProc[*]} | tr " " "\n" | sort > .zerovoxprocs
# echo ${allProcIDs[*]} | tr " " "\n" | sort > .allprocs

# #use compare to only show lines in all that aren't in zeros (-1) and aren't shared (-3).
# gt0voxproc=$(comm -13 .zerovoxprocs .allprocs | sort -n)

# for p in $gt0voxproc; do
#     echo $p
# done
