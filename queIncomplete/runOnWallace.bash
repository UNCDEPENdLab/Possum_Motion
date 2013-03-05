#!/usr/bin/env bash
# arg1 is incomplete file: a tab delim 'sim_cfg {nostarted|incomplete} njobs jobid' listing of incomplete task
# or no argument to have this file generated
#

incmpFile=$1
if [ -z "$incmpFile" -o ! -r "$incmpFile" ]; then
	incmpFile=$(date +%F:%H:%M).unfinished
        lscmd='ls -d /brashear/hallquis/possum_rsfcmri/*'
        [[ $HOSTNAME =~ wallace ]] && lscmd="ssh blacklight 'ls -d /brashear/hallquis/possum_rsfcmri/\*'"
	for i in $($lscmd); do 
	  f=$(basename $i)
          # set number of jobs by partially sourcing the sim_cfg
	  export $(grep njobs ~/Possum_Motion/sim_cfg/${f%_*-*}) 

          # list all jobs and compare to those with possum output to get those that have not started
          # TODO: use ls logs/$i |grep possumlog instead of ls output/
	  comm -13 <(ls $i/output|cut -d_ -f2 |sort -n) <(perl -le "print \$_ for (0..$njobs-1)")|sed -e "s;^;$f\tnotstarted\t$njobs\t;"

          # find possum logs that have not finished (logs that don't match 'finished')
	  grep -L 'Possum finished generating the signal' $i/logs/possumlog* |
	    xargs -n1 basename | cut -f2 -d_ |sort -n | perl -lne "print \"$f\tincomplete\t$njobs\t\", \$_-1"

	done | tee $incmpFile
fi

## Run through jobs

[[ ! $HOSTNAME =~ wallace|gromit ]] && echo "NEED TO BE ON WALLACE!" && echo "scp blacklight:$(pwd)/$incmpFile ./; $0 $incmpFile" && exit 2

## Tmux
# session name
s_name=runPossumJobs
# start new session (errors if already exists)
tmux new-session -s $s_name -d

## generic possum settings
inputDir=/home/foranw/src/Possum_Motion/defaults
sim_cfg_dir=/home/foranw/src/Possum_Motion/sim_cfg
motionDir=$inputDir/motion_parameters
export SCRATCH=/home/foranw/src/Possum_Motion/scratch/
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
  
  # check that its not already running on wallace (TODO: check that this works -- does buf_name get truncated in tmux output?)
  tmux list-windows | grep $buf_name 2>/dev/null && echo -e "$buf_name already running?!\n run on your own:\n $possumCmd" && continue

  ## TODO: check that it hasn't already finished running on wallace
  # ls $SCRATCH/$sim_cfg*/*$jobid 2>/dev/null && echo "already have a log file on wallace" && continue
  
  # run in the background and within tmux
  echo tmux new-window -t $s_name -n $buf_name -d "$possumCmd"
  echo
  tmux new-window -t $s_name -n $buf_name -d "$possumCmd"
done
