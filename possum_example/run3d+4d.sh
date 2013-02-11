#!/usr/bin/env bash

# run possum debug for 4d and 3d

set -e

# paths are all relative, so go to script directory
cd $(dirname $0)

# make sure we have the 4d files
[ ! -r 4d.nii.gz -o ! -r 4dtc.txt ] && echo "making 4d!" && ./mk4dMatch3d.sh

[ ! -d debug ] && mkdir debug

PATH="../bin/linux/:$PATH"
inputDir=../possum_example/
possumBaseCmd="
possum.debug
  --nproc=1 --procid=0
  -o useless-output.jnk
  -m $inputDir/zeromotion
  -i $inputDir/brain.nii.gz
  -x $inputDir/MRpar_3T
  -f $inputDir/slcprof
  -p $inputDir/example_pulse
"
$possumBaseCmd  --activ=3d.nii.gz   --activt=3dtc.txt --debugprefix=debug/3d   | tee debug/3d.log
$possumBaseCmd  --activ4D=4d.nii.gz --activt4D=4dtc.txt --debugprefix=debug/4d | tee debug/4d.log
