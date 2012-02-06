#!/usr/bin/env sh

###                 ###
### options for pbs ###
###                 ###

#PBS -l ncpus=16
#PBS -l walltime=24:00:00
#dont use leading zeros
#PBS -q batch

# PARAMETERS
# expect 
#  o ActivePrefix
#  o MotionFile
#  o simID
#
source environment.sh
source simIDVars.sh



##############
### Checks ###
##############

[ -n "$#" ] || die "No Arguments to queuer: no job IDs!"

## did we get the vars we needed?
for need in "simID" "MotionFile" "BASEDIR"; 
   do
   have $need  ||  die "$need is not set, use -v" 
done


## do all of the files we need exist (and are readable)
for f in "BrainFile" "PulseFile" "MotionFile" \
         "ActivationFile" "RFFile" "MRFile"; 
   do
   exists $f   ||  die "$(eval echo "$f \$$f is not readable")"
done

#  check for log file, make if DNE
dircheck "LogDir"
dircheck "SimOutDir"


##############################
### Possum for each job id ###
##############################

for jobID in $@; do
   

   # job comleltion check/parse requires the log file be named only a number
   LogFile="$LogDir/${jobID}"

   let jobID--  #possum is zero based, the log structure is not!

   ### testing: just say we got here
   echo 
   echo possum                          \
       --nproc=$TotalCPUs               \
       --procid=$jobID                  \
       -o $SimOutDir/possum_${jobID}    \
       -m ${MotionFile}                 \
       -i ${BrainFile}                  \
       -x ${MRFile}                     \
       -f ${RFFile}                     \
       -p ${PulseFile}                  \
       --activ4D=${ActivationFile}      \
       --activt4D=${ActivationTimeFile} \
        ">" $LogFile
   echo


   ### 

   #ja

   #possum                               \
   #    --nproc=$TotalCPUs               \
   #    --procid=$jobID                  \
   #    -o $SimOutDir/possum_${jobID}    \
   #    -m ${MotionFile}                 \
   #    -i ${BrainFile}                  \
   #    -x ${MRFile}                     \
   #    -f ${RFFile}                     \
   #    -p ${PulseFile}                  \
   #    --activ4D=${ActivationFile}      \
   #    --activt4D=${ActivationTimeFile} \
   #      > $LogDir/possumlog_${simID}_${jobID} &


   #ja -t > $SCRATCH/log/${simID}_${jobID}.job.log
done
