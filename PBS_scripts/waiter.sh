#!/usr/bin/env sh

# combine all of possums outputs
#   o LogDir / TotalCPUs as jobID -> LogFile 
#
#   -            jobid=1,   procid=0,   output=possum_0
#   -          jobid=128, procid=127, output=possum_127



source environment.sh
source simIDVars.sh    # should have exported needed simID, will die otherwise

# make sure we have access to the pulsefile
if [ ! -r $PulseFile   ]; then echo "ERROR PulseFile ($PulseFile) not readable"; exit 1; fi

# check there is a log file (also confirms simID is set)
if [ ! -d $LogDir   ]; then echo "ERROR No log directory ($LogDir) for combining possum runs???"; exit 1; fi


# last log file would be named the same as the number of cpus used
LogFile=$LogDir/$TotalCPUs

# check for the status of the last log file at some interval 
#   maybe sleep for walltime
while sleep 3000; do

  # if log file isn't readable, keep waiting
  [ -r $LogFile ] || continue

  # if log file has the last line, move on
  # [ -z "$(sed -ne '/^Possum finished generating/p' $LogFile)" ] || break
  
  # cannot do above, last log might be created before first!
  # instead count all the files matching and compare to total
  # UNTESTED
  [ "$(grep -l '^Possum finished generating' $LogDir/* |wc -l)" -ge $TotalCPUs ] && break

done


# execute with qsub?
set -xe
possum_sum -i ${SimOutDir}/possum_ -o ${SimOutDir}/combined -n ${TotalCPUs} -v
signal2image -i ${SimOutDir}/combined -p $PulseFile -o ${SimOutDir}/Brain_${simID}
set +xe
