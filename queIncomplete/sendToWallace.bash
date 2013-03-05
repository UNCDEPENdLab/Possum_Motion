#!/usr/bin/env bash
# arg1 is incomplete file: a tab delim 'sim_cfg {nostarted|incomplete} jobid' listing of incomplete task
# or no argument to have this file generated
#

incmpFile=$1
if [ -z "$incmpFile" -o ! -r "$incmpFile" ]; then
	incmpFile=$(date +%F:%H:%M).unfinished
        lscmd='ls /brashear/hallquis/possum_rsfcmri/*'
        [[ $HOSTNAME =~ wallace ]] && lscmd="ssh blacklight 'ls /brashear/hallquis/possum_rsfcmri/\*'"
	for i in $($lscmd); do 
	  f=$(basename $i)
	  export $(grep njobs ~/Possum_Motion/sim_cfg/${f%_*-*}) 
	  comm -13 <(ls $i/output|cut -d_ -f2 |sort -n) <(perl -le "print \$_ for (0..$njobs-1)")|sed -e "s;^;$f\tnotstarted\t;"
	  grep -L 'Possum finished generating the signal' $i/logs/possumlog* |
	    xargs -n0 basename | cut -f2 -d_ |sort -n | sed -e "s;^;$f\tincomplete\t;"
	done | tee $incmpFile
fi

## Run through jobs

[[ ! $HOSTNAME =~ wallace|gromit ]] && echo "NEED TO BE ON WALLACE!" && echo "scp blacklight:$(pwd)/$incmpFile ./; $0 $incmpFile" && exit 2
s_name=runPossumJobs
sim_cfg_dir="~foranw/src/Possum_Motion/sim_cfg"
tmux new-session -s $s_name -d
cat $incmpFile | while read sim_cfg type jobid; do
  echo $sim_cfg $jobid
  source $sim_cfg_dir/$sim_cfig
  echo tmux new-window -t $s_name -n ${sim_cfg}_$jobid -d "possum"
done
