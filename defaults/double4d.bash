#!/bin/bash

#double the 150 activation for the "hold" approach to activation (where there is little interpolation from one TR to the next because the two volumes with identical activations are used to "hold" a value).

fslsplit 10895_POSSUM4D_bb264_roiAvg_fullFreq_x5.nii.gz tcat
mergcmd='fslmerge -tr 10895_POSSUM4D_bb264_roiAvg_fullFreq_x5_DOUBLE.nii.gz '
for f in $( ls tcat* | sort -n ); do
    mergecmd="$mergecmd $f $f" #double each image
done
mergecmd="$mergecmd 2.0"
eval $mergecmd
rm -f tcat*
