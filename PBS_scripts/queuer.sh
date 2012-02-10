#!/usr/bin/env sh

###                 ###
### options for pbs ###
###                 ###

#PBS -l ncpus=16
#PBS -l walltime=20:00:00
#dont use leading zeros
#PBS -q batch

# PARAMETERS
# expect 
#  o ActivePrefix
#  o MotionFile
#  o simID
#


if [[ $HOSTNAME =~ skynet ]]; then
   PBSSCRIPTDIR="/Volumes/Serena/possum_speedup_tests_xsede/gitFromBlacklight/Possum-02-2012/PBS_scripts/"
else
   PBSSCRIPTDIR=$HOME/Possum-02-2012/PBS_scripts/
fi

source $PBSSCRIPTDIR/environment.sh
source $PBSSCRIPTDIR/simIDVars.sh



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
dircheck "QueLogDir"
dircheck "SimOutDir"


echo "SCRACTC: $SCRATCH"
echo "LogDir:  $LogDir"
echo "Jobs:    $ARGS"
echo "Host:    $HOSTNAME"
echo "SimID:   $simID"
echo "Mfile:   $MotionFile"
echo "Afile:   $ActivationFile"

##############################
### Possum for each job id ###
##############################

IFS=:
for jobID in $ARGS; do
   

   # job comleltion check/parse requires the log file be named only a number
   LogFile="$LogDir/${jobID}"

   let jobID--  #possum is zero based, the log structure is not!

   # run or print out what we would run
   if [ "$REALLYRUN" == "1" ]; then

      #[[ $HOSTNAME =~ blacklight ]] && ja
      # hostname may not be blacklight but anyway
      # don't really care what the host name is
      # just that it has ja
      which ja && ja

      set -x
      possum                               \
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
            > $LogFile &
      set +x


      #[[ $HOSTNAME =~ blacklight ]] && ja -chlst > $QueLogDir/${simID}_${jobID}.job.log
      which ja &&  ja -chlst > $QueLogDir/${simID}_${jobID}.job.log

      #-c command report
      #-h Kilobytes of largest memory usage
      #-l "additional info"
      #-s summary report
      #-t terminates accounting
   else
      ## testing: just say we got here
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
   fi


done

echo "forked jobs!"
date

time wait 

echo "finished!"
date
