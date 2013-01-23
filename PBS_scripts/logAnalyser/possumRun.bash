#!/usr/bin/env sh

function possumRun { 
   echo -n "start: "; date
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
            > $LogFile 
   echo -n "finished: "; date
}

