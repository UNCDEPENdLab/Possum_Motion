#!/usr/bin/env sh

function possumRun { 
   runum=$1
   echo -n "start: "; date
   echo possum                               \
          --nproc=$TotalCPUs               \
          --procid=$jobID                  \
          -o $SimOutDir/possum_${runum}    \
          -m ${MotionFile}                 \
          -i ${BrainFile}                  \
          -x ${MRFile}                     \
          -f ${RFFile}                     \
          -p ${PulseFile}                  \
          --activ4D=${ActivationFile}      \
          --activt4D=${ActivationTimeFile} \
          #  > $LogFile 
   echo -n "finished: "; date
}

