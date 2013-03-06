#!/usr/bin/env bash
#
#  prompt to run unfinished possum jobs in tmux on wallace
#
# if run on wallace, script is run on blacklight, output is transfered to wallace, script is finished on wallace
# if run on blacklight, script is run and instructions on how to run on wallace are printed
#
# usage: 
#  @wallace:     ./runOnWallace.bash
#  @blacklight:  ./runOnWallace.bash; ssh wallace; scp blacklight:<unfinishedfile> ./; ./runOnWallace.bash <unfishedfile>
#
# method:
#  look at $SCRATCH/possum_rsfcmri for runs
#   check output and log for incomplete jobs for each run, output to file
#  parse file, prompt to run each incomplete/unfinished job in tmux on wallace
#
# NOTE: 
#       TODO: check for too many jobs running on wallace
#       TODO: check job is already complete on wallace
#       DONE: check job not already running on wallace
#
# inputs:
#   arg1 is incomplete file: a tab delim 'sim_cfg {nostarted|incomplete} njobs jobid' listing of incomplete task
#   if no argument, this file is generated
#

incmpFile=$1
if [ -z "$incmpFile" -o ! -r "$incmpFile" ]; then

   # run this script on blacklight, then again here with the new file
   if [[ $HOSTNAME =~ wallace|gromit ]]; then
     cd $(dirname $0)
     scpcmd=$(ssh blacklight '~/Possum_Motion/queIncomplete/runOnWallace.bash' | tee >(cat >&2)| tail -n1)
     eval $scpcmd
     exit
   fi

   # create new incomplete file
   incmpFile=$(date +%F:%H:%M).unfinished

   for i in $(ls -d /brashear/hallquis/possum_rsfcmri/*); do 
     f=$(basename $i)
     # set number of jobs by partially sourcing the sim_cfg
     export $(grep njobs ~hallquis/Possum_Motion/sim_cfg/${f%_*-*}) 
   
     # list all jobs and compare to those with possum output to get those that have not started
     comm -13 <(ls $i/logs |perl -F_ -sanle 'print $F[1]-1 if /possumlog/ ' |sort -n) <(perl -le "print \$_ for (0..$njobs-1)")|sed -e "s;^;$f\tnotstarted\t$njobs\t;"
   
     # find possum logs that have not finished (logs that don't match 'finished')
     grep -L 'Possum finished generating the signal' $i/logs/possumlog* |
       xargs -n1 basename | cut -f2 -d_ |sort -n | perl -lne "print \"$f\tincomplete\t$njobs\t\", \$_-1"
   
     # TODO: add another comm -23 to remove ids that match  $SimOutputDir/running-$jobID
   done | tee $incmpFile
fi

## Run through jobs

[[ ! $HOSTNAME =~ wallace|gromit ]] && echo "NEED TO BE ON WALLACE!" && echo "scp blacklight:$(pwd)/$incmpFile ./; ./$(basename $0) $incmpFile" && exit 2

## Tmux
# session name
s_name=runPossumJobs
# start new session (errors if already exists)
tmux new-session -s $s_name -d

## generic possum settings
possumRoot=$( cd $(dirname $0)/..; pwd )
inputDir=${possumRoot}/defaults
sim_cfg_dir=${possumRoot}/sim_cfg
motionDir=$inputDir/motion_parameters
export SCRATCH=$HOME/scratch
SimRoot="$SCRATCH/possum_rsfcmri"

## loop through incomplete jobs file
# cat abuse :)
cat $incmpFile | while read sim unfin_type njobs jobid; do
  sim_cfg=${sim%_*-*}
  buf_name=${sim_cfg}_$jobid
  echo $unfin_type: $sim_cfg $jobid

  # run the job?
  echo -en "\tRUN THIS JOB? (y|N): "
  read  resp < /dev/tty
  [[ ! $resp =~ y ]] && echo 'skipping' && continue

  source $sim_cfg_dir/$sim_cfg
  SimOutputDir=$SimRoot/$sim/output
  SimLogDir=$SimRoot/$sim/logs
  [ ! -d $SimOutputDir ] && mkdir -p $SimOutputDir
  [ ! -d $SimLogDir ] && mkdir -p $SimLogDir

  ##TODO: pull this from ../qsub_possum4d.bash instead of rewritting here
  possumCmd="possum \\
     --nproc=$njobs \\
     --procid=$jobid \\
     -o $SimOutputDir/possum_${jobid} \\
     -m $motion \\
     -i $t1input \\
     -x $mrPar \\
     -f $slcprof \\
     -p $pulse \\
     --activ4D=$activ4D \\
     --activt4D=$activTime"
  
  # check that its not already running on wallace (TODO: check that this works -- does buf_name get truncated in tmux output? -- looks like no truncation)
  tmux list-windows | grep $buf_name 2>/dev/null && echo -e "$buf_name already running?!\n run on your own:\n $possumCmd" && continue

  ## check output file doesn't already exist on wallace
  [ -r $SimOutputDir/possum_${jobid} ] && echo "already run on wallace, remove $SimOutputDir/possum_${jobid} to rerun" && continue

  # run in the background and within tmux
  echo "Logging to $SimLogDir/$buf_name.log"
  echo -e "$(date +%F:%H:%M)\ntmux new-window -t $s_name -n $buf_name -d \"$possumCmd\"" | tee $SimLogDir/$buf_name.log
  echo
  tmux new-window -t $s_name -n $buf_name -d "$possumCmd | tee -a $SimLogDir/$buf_name.log"
done
