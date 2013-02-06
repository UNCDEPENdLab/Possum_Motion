#!/usr/bin/env sh
## 
##  USAGE:
##    $0 logdirectory
##    * logdirectory must exist
##  EXAMPLE:
##    $0 /brashear/hallquis/possum_rsfcmri/
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
##    NOTE: Need to remove echo before possum in 'PossumRun.bash' 
##   
##   
##  ABOUT:
##    combines possumLogtime.pl and generatePartitions.R
##    to choose the best combination of grouped incomplete possum jobs
##    such that total run time and processor idle time are minimized
##   
##   * estimate possum job run times
##      find $logdirectory -type f |grep -v 0001 | possumLogtime.pl  > possumTimes.txt
##   * optimize job grouping for least idle processor time
##      Rscript generatePartitions.R possumTimes.txt ./
##   * submitting to qsub (doesn't help much there)
##      qsub -N "finish up possum"  finish-with-*-PBS.bash
## 
##END

set -e 
set -x
ncpus=256
# print help/usage if unexpected input
[[ -z "$1" || ! -d "$1" ]] && sed -n "/##END/q;s:\$0:$0:g;s/^## //p" $0 && exit 1

# absolute paths
scriptdir=$(cd $(dirname $0); pwd)
logdirs=$(cd $1; pwd)

# output
outdir=$scriptdir/finish_$(date +%F)
[ -d $outdir ] &&  rm -r $outdir   # removed because we always append to possumTimes.txt
mkdir -p $outdir

for logdir in $logdirs/*/logs/; do
  echo "**$logdir**"
  # what config file is used
  sim_cfg=$(basename $(dirname $logdir))
  sim_cfg=${sim_cfg%_*}
  # check sim_cfg exists
  [ ! -r $HOME/Possum_Motion/sim_cfg/$sim_cfg ] && echo "Unknown $sim_cfg" && continue #&& exit 1
  
  # estimate run times of possum jobs
  #find $logdir -type f -name possumlog_\* | egrep -v 0001 | $scriptdir/possumLogtime.pl $sim_cfg >> $outdir/possumTimes.txt
  # we probably know the exact structure, so lets do that insted of globbing
  
  perl -e "print '$logdir/possumlog_'.sprintf('%04',\$_) for (2...$ncpus)" |
    $scriptdir/possumLogtime.pl $sim_cfg >> $outdir/possumTimes.txt
  
done

# remove duplicate header from perl script
sed -ie '1,1p;/^sim_cfg\tp/d' $outdir/possumTimes.txt


if [ -r /usr/share/modules/init/sh ]; then
  echo 'loading R'
  source /usr/share/modules/init/sh
  module load R
fi

# group remaining run times into equal sized bins
# created $outdir/finish-with-#-PBS.bash

# need to be here for source command
cd $scriptdir
Rscript $scriptdir/blockTimes.R "$outdir/possumTimes.txt" "$outdir/possumTime_withExp.txt"
Rscript $scriptdir/generatePartitions.R "$outdir/possumTime_withExp.txt" "$outdir/"

# change 
cd $outdir
# give the qsub script the right configureation name
#sed -i "s:__simName__:$sim_cfg:g" $outdir/finish-with*bash

cp $scriptdir/possumRun.bash $outdir
echo qsub $outdir/finish-with*

