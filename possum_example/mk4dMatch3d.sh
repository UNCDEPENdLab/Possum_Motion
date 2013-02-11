#!/usr/bin/env bash

####
# create the 4d file we expect possum to be using with 3d file + timecourse
# 
# go from 
#     possum -activ   3d.nii.gz -activt   3dtc.txt
# to
#     possum -activ4D 4d.nii.gz -activt4D 4dtc.txt
#
####

set -e

#POSSUM should not care about the TR in the NIfTI header -- just the --activt4D timecourse file

# 4d time course build with append, so remove if already exists
[ -r example_activ4dtc.txt ] && rm example_activ4dtc.txt

# scale the 3d volume by the value in the time course file
# name after time point

cat activation3Dtimecourse |
 while read time value; do 
  3dcalc -a activation3D.nii.gz \
         -expr "a*$value" \
         -prefix $(printf "%03d" $time).nii.gz
  echo $time >> example_activ4Dtc.txt 
 done

# make 4d: bring all the scaled volumes together
3dTcat -prefix example_activ4D.nii.gz [01][0-9][0-9].nii.gz 
rm [01][0-9][0-9].nii.gz 

# Now should have a 4d file that is the 3d activation multiplied by the scaling factor.
# This should yield exactly the same output as the stock POSSUM example with 3d input.

# assume TR doesn't matter or we need to pad 3dTcalc with blanks
3drefit -TR 2.0 example_activ4D.nii.gz
