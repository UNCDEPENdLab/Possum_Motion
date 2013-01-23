#!/usr/bin/env sh
#set -x
set -e

SimOutBase=$SCRATCH/possum_rsfcmri

while [ -n "$1" ]; do
    case $1 in 
	-sim_cfg)  SimRun="$2";     shift 2;; # simulation configuration
	-njobs)    njobs=$2;        shift 2;; # number of jobs expected
	-pulse)    pulse="$2";      shift 2;; # pulse file required to reconstruct images
	*) echo -e "[Unrecognized option: '$1']";
	    exit 1;;
    esac
done

[ -z "$njobs" ] && echo "Must specify number of jobs expected: -njobs <n>." && exit 1
[ -z "$SimRun" ] && echo "Must specify simulation configuration: -sim_cfg <string>." && exit 1
[ -z "$pulse" ] && echo "Must specify pulse file basename: -pulse <string>" && exit 1

inputDir=$HOME/Possum_Motion/defaults

#use return code from ls to determine if output directory exists.
#good method for finding whether dir exists 
#SimOutDir=$( find $SimOutBase -type d -maxdepth 1 -name '${SimRun}*' -print -quit )

#ls -d "${SimOutBase}/${SimRun}"*
#echo $?

if ls -d "${SimOutBase}/${SimRun}"* > /dev/null 2>&1; then
    SimOutDir=$( ls -d "${SimOutBase}/${SimRun}"* )
else 
    echo "Unable to locate output directory for simulation config: $SimRun"
    exit 1
fi

noutputs=$( find $SimOutDir/output -iname "possum_*" -type f | wc -l )

if [ $noutputs -ne $njobs ]; then
    echo "Number of possum outputs: $noutputs. Num expected: $njobs."
    exit 1
fi

echo "outdir: $SimOutDir"
echo "noutputs: $noutputs"

[ ! -d "${SimOutDir}/combined" ] && mkdir "${SimOutDir}/combined"

possum_sum -i ${SimOutDir}/output/possum_ -o ${SimOutDir}/combined/possum_combined -n ${njobs} -v 2>&1          |
   tee $SimOutDir/logs/possum_sum-$(date +%F).log

signal2image -i ${SimOutDir}/combined/possum_combined -a --homo -p $inputDir/$pulse -o "${SimOutDir}/combined/${SimRun}_possum_simt2" |
   tee $SimOutDir/logs/signal2image-$(date +%F).log
