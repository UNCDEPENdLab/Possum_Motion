#!/usr/bin/env sh

###                 ###
### options for pbs ###
###                 ###

#PBS -l ncpus=112
#PBS -l walltime=54:00:00
#PBS -q batch
#PBS -j oe
#PBS -M hallquistmn@upmc.edu

#To test a POSSUM run, qsub with the TEST option in the debug queue. For example,
#  qsub -l walltime=15:00 -l ncpus=16 -q debug -v TEST=1,SIMRUN=10895_nomot_roiAvg_fullFreq_x5 qsub_possum4d.bash

source /usr/share/modules/init/bash

ncpus=$PBS_NCPUS #set number of jobs to be run equal to cpus requested for qsub

inputDir=$HOME/Possum_Motion/defaults
motionDir=$inputDir/motion_parameters

function exists     { eval   file=\$$1;    [ -r "$file"   ] ; }
function dircheck   { eval   dirt=\$$1;    [ -d "$dirt"   ] || mkdir -p $dirt; }
## how should we die
function die {
   echo $1 #| tee >(cat 1>&2) # hit stdout and stderr, need bash, qsub has .e and .o logs
   exit 1
}


SimRoot="$SCRATCH/possum_rsfcmri"

if [ -n "$SIMRUN" ]; then
    source "$HOME/Possum_Motion/sim_cfg/$SIMRUN"

    simExist=$(
	ls -d "${SimRoot}/${simName}_"[0-9][0-9][A-Z]* 2>/dev/null |
	perl -lne "print if m:/${simName}_\d{2}(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec):"
	)
    if [ -z "$simExist" ]; then
	SimTargetDir=${simName}_$(date +%d%b%Y-%R)
    else 
	echo "Resuming run: ${simExist}"
	SimTargetDir=$( basename $simExist )
    fi

else
    SimTargetDir=simout_$(date +%d%b%Y-%R) #default to runtime/date
fi



LogDir="$SimRoot/$SimTargetDir/logs"
SimOutputDir="$SimRoot/$SimTargetDir/output"

#  check for log file, make if DNE
dircheck "LogDir"
dircheck "SimOutputDir"

#defaults, if not set in the sim cfg
[ -z "$motion" ]    && motion="$motionDir/zeromotion"
[ -z "$t1input" ]   && t1input="$inputDir/possum_10895_fast.nii.gz"
[ -z "$activ4D" ]   && activ4D="$inputDir/10895_POSSUM4D_bb264_roiAvg_fullFreq.nii.gz"
[ -z "$activTime" ] && activTime="$inputDir/activt_150"
[ -z "$mrPar" ]     && mrPar="$inputDir/MRpar_3T"
[ -z "$slcprof" ]   && slcprof="$inputDir/slcprof"
[ -z "$pulse" ]     && pulse="$inputDir/tr2_te30_pulse"
[ -z "$njobs" ]     && njobs=384 #allow njobs to be passed with qsub -v
[ -z "$TEST" ]      && TEST=0 #default to a full simulation

qsubLog="$LogDir/qsublog_$(date +%d%b%Y-%R)"
#header of log file
echo "SIMRUN:       $SIMRUN"       | tee -a "$qsubLog"
echo "SCRATCH:      $SCRATCH"      | tee -a "$qsubLog"
echo "OutputDir:    $SimOutputDir" | tee -a "$qsubLog"
echo "LogDir:       $LogDir"       | tee -a "$qsubLog"
echo "Host:         $HOSTNAME"     | tee -a "$qsubLog"
echo "Motion file:  $motion"       | tee -a "$qsubLog"
echo "T1 input:     $t1input"      | tee -a "$qsubLog"
echo "activ 4D:     $activ4D"      | tee -a "$qsubLog"
echo "activ time:   $activTime"    | tee -a "$qsubLog"
echo "mr par:       $mrPar"        | tee -a "$qsubLog"
echo "slc prof:     $slcprof"      | tee -a "$qsubLog"
echo "pulse:        $pulse"        | tee -a "$qsubLog"
echo "njobs:        $njobs"        | tee -a "$qsubLog"
echo "ncpus:        $ncpus"        | tee -a "$qsubLog"
echo ""

#verify that required files are present
for f in "motion" "t1input" "activ4D" "pulse" \
         "activTime" "mrPar" "slcprof";
   do
   exists $f   ||  die "$(eval echo "$f \$$f is not readable")"
done

##############################
### Possum for each job id ###
##############################

FSLOUTPUTTYPE=NIFTI_GZ
PATH=$HOME/Possum_Motion/bin/linux:${PATH}
export PATH FSLOUTPUTTYPE

which ja && ja

cleanup () {
    echo "Exiting script due to sigint/sigterm/exit"
    ja -chlst    
    # remove running locks
    rm $SimOutputDir/running-*
    find $SimOutputDir -type f | xargs chmod g+rw #make sure Will has permission
    find $SimOutputDir -type d | xargs chmod g+rx
    exit 0 #make sure the script exits and doesn't run another person
}
trap cleanup SIGINT SIGTERM

for ((jobID=1; jobID <= njobs ; jobID++)); do

    # job completion check/parse requires the log file be named only a number
    JobLog="$LogDir/possumlog_$(printf "%04d" ${jobID})"

    let "jobID_0 = jobID - 1"  #possum is zero based, the log structure is not!

   # wait here until number of running jobs is <= ncpus

    joblist=($(jobs -p))
    curjoblist=${joblist[@]}
    echo                                  >> "$qsubLog"
    echo "---------"                      >> "$qsubLog"
    echo "Jobs running: ${#joblist[*]}"   >> "$qsubLog"
    echo "CPU limit: ${ncpus}"            >> "$qsubLog"
    echo
    if [[ ! -z ${joblist} && $jobID > $ncpus ]]; then
        ps -o pid,args -p ${joblist[@]}   >> "$qsubLog"
    fi
    echo "---------"                      >> "$qsubLog"

    while (( ${#joblist[*]} >= ${ncpus} ))
    do
        sleep 180
        joblist=($(jobs -p))

        numrunning=${#joblist[*]}
        #echo "Number of processes running: ${numrunning}"

        if [[ "${joblist[@]}" != "${curjoblist[@]}" && $jobID > $ncpus ]]; then
	    echo                                   >> "$qsubLog"
	    echo "---------"
	    echo "Jobs running: ${#joblist[*]}"    >> "$qsubLog"
	    echo "CPU limit: ${ncpus}"             >> "$qsubLog"
	    echo                                   >> "$qsubLog"
            if [ ! -z ${joblist} ]; then
                ps -o pid,args -p ${joblist[@]}    >> "$qsubLog"
            fi
	    echo "---------"                       >> "$qsubLog"

            curjoblist=${joblist[@]}
        fi
    done

    #don't re-run POSSUM if file already exists
    if [ -r "$SimOutputDir/possum_${jobID_0}" ]; then
	echo "Possum output already exists. Skipping job ${jobID}." | tee -a "$qsubLog"
	echo "File: $SimOutputDir/possum_${jobID_0}"                | tee -a "$qsubLog"
    else
	
	possumCmd="possum \\
           --nproc=$njobs \\
           --procid=$jobID_0 \\
           -o $SimOutputDir/possum_${jobID_0} \\
           -m $motion \\
           -i $t1input \\
           -x $mrPar \\
           -f $slcprof \\
           -p $pulse \\
           --activ4D=$activ4D \\
           --activt4D=$activTime"

	echo "Start time: $(date +%d%b%Y-%R)" > $JobLog
	echo "Start time epoch(s): $(date +%s)" >> $JobLog
	echo -e "${possumCmd}\n\n" >> $JobLog
	
           # touch a lock
	date +%F_%R > $SimOutputDir/running-$jobID
	
	echo "$possumCmd" | tee -a "$qsubLog" #echo the possum command to the screen

	if [ "$TEST" -ne "1" ]; then
            # run the CMD by echoing within a command substitution
            # need tr to replace backslashes with a space to avoid escaping issues
	    #$( echo "$possumCmd" | tr "\\\\" " " ) >> $JobLog &
	    bash -c "$possumCmd" >> $JobLog 2>&1 & #for some reason, sometimes the echo above was trying to run the whole thing as a quoted command
	    pid=$!

	    sleep 1 #give the loop a second to rest when forking a bunch of jobs at the beginning of the run 
	fi
    fi   
done

echo "forked jobs!"
date

time wait 

echo "finished!"
date

cleanup #call here, rather than trap signal EXIT because that will execute when one process finishes and exits



##detritus

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

      #[[ $HOSTNAME =~ blacklight ]] && ja -chlst > $QueLogDir/${simID}_${jobID}.job.log
      #which ja &&  ja -chlst > $QueLogDir/${simID}_${jobID}.job.log
       
      #-c command report
      #-h Kilobytes of largest memory usage
      #-l "additional info"
      #-s summary report
      #-t terminates accounting


#    if [ "$TEST" == "1" ]; then
#       ## testing: just say we got here
#       echo 
#       echo possum \
#           --nproc=$njobs \
#           --procid=$jobID_0 \
#           -o $SimOutputDir/possum_${jobID_0} \
#           -m $motion \
#           -i $t1input \
#           -x $mrPar \
#           -f $slcprof \
#           -p $pulse \
#           --activ4D=$activ4D \
#           --activt4D=$activTime \
#             ">" $JobLog
#       echo

#    else
