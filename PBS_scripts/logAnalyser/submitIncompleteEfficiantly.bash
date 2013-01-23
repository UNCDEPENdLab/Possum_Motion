#!/usr/bin/env sh
## USAGE:
##   $0 logdirectory
##   * logdirectory must exist
## EXAMPLE:
##   $0 /brashear/hallquis/possum_rsfcmri/10895_nomot_roiAvg_fullFreq_16Jan2013-00:12/log
##
## OUTPUT:
##   bash script ready for qsub
##
## ABOUT:
##   combines possumLogtime.pl and generateParitions.R
##   to choose the best combination of grouped incomplete possum jobs
##   such that total run time and processor idle time are minimized
##
##END

# print help/usage if unexpected input
[[ -z "$1" || ! -d "$1" ]] && sed -n "/##END/q;s:\$0:$0:g;s/^## //p" $0 && exit 1

# absolute paths
scriptdir=$(cd $(dirname $0); pwd)
logdir=$(cd $1; pwd)

# what config file is used
sim_cfg=$(basename $(dirname $logdir))
sim_cfg=${sim_cfg%_*}
# check sim_cfg exists
[ ! -r $HOME/Possum_Motion/sim_cfg/$sim_cfg ] && echo "Unknown $sim_cfg" && exit 1


# output
outdir=$scriptdir/finish_${sim_cfg}_$(date +%F)
[ ! -d $outdir ] && mkdir -p $outdir
cd $outdir

# estimate run times of possum jobs
ls -1 $logdir | egrep -v 0001 | $scriptdir/possumLogtime.pl > $outdir/possumTimes.txt

# group remaining run times into equal sized bins
# created $otudir/finish-with-#-PBS.bash
RScript $scriptdir/generateParitions.R "$outdir/possumTimes.txt" "$outdir/"

cp $scriptdir/possumRun.bash $outdir
echo qsub $outdir/finish-with*

