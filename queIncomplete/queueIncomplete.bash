#!/usr/bin/env sh
## 
##  USAGE:
##    $0 logdirectory
##    * logdirectory must exist
##  EXAMPLE:
##    $0 /brashear/hallquis/possum_rsfcmri/10895_nomot_roiAvg_fullFreq_16Jan2013-00:12/logs/
##  
##  OUTPUT:
##    bash script ready for qsub
##    last line of output will be qsub command
##   
##    creates a finish_* directory within queIncomplete/
##    with two scripts
##      * finish-with-#-PBS.bash -- to be submited with  qsub
##      * PossumRun.bash         -- copy of local, sourced to set up environment
##   
##    NOTE: Need to remove echo before possom in 'PossumRun.bash' 
##   
##   
##  ABOUT:
##    combines possumLogtime.pl and generateParitions.R
##    to choose the best combination of grouped incomplete possum jobs
##    such that total run time and processor idle time are minimized
##   
##   * estimate possum job run times
##      find $logdirectory -type f |grep -v 0001 | possumLogtime.pl  > possumTimes.txt
##   * optimize job grouping for least idle processor time
##      Rscript generateParitions.R possumTimes.txt ./
##   * submitting to qsub (doesn't help much there)
##      qsub -N "finish up possum"  finish-with-*-PBS.bash
## 
##END

set -e 
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

# need to be here for source command
cd $scriptdir

# estimate run times of possum jobs
find $logdir -type f | egrep -v 0001 | $scriptdir/possumLogtime.pl > $outdir/possumTimes.txt

if [ -r /usr/share/modules/init/sh ]; then
  echo 'loading R'
  source /usr/share/modules/init/sh
  module load R
fi
# group remaining run times into equal sized bins
# created $otudir/finish-with-#-PBS.bash
echo Rscript $scriptdir/generateParitions.R "$outdir/possumTimes.txt" "$outdir/"
Rscript $scriptdir/generateParitions.R "$outdir/possumTimes.txt" "$outdir/"

cd $outdir

# give the qsub script the right configureation name
sed -i "s:__simName__:$sim_cfg:g" $outdir/finish-with*bash

cp $scriptdir/possumRun.bash $outdir
echo qsub $outdir/finish-with*

