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

#NOTE: does possum care what the TR is?
# does it try to interporlate voxel values at times in activet using the volumes in activ4d as TR time appart
# or does it use the activet input list as the time for each volume and disregard TR

# 3dtc.txt  is a link to ../possum_example/activation3Dtimecourse
# 3d.nii.gz is a link to ../possum_example/activation3D.nii.gz

# 4d time course build with append, so remove if already exists
[ -r 4dtc.txt ] && rm 4dtc.txt
# scale the 3d volume by the value in the time course file
# name after time point

cat 3dtc.txt |
 while read time value; do 
  3dcalc -a 3d.nii.gz \
         -expr "a*$value" \
         -prefix $(printf "%03d" $time).nii.gz
  echo $time >> 4dtc.txt 
 done

# make 4d: bring all the scaled volumes together
3dTcat -prefix 4d-noscale.nii.gz [01][0-9][0-9].nii.gz 
rm [01][0-9][0-9].nii.gz 

# rescale activation to T2*
3dcalc -a 4d-noscale.nii.gz \
       -expr '((30/(30/51-log(a)))-51)/1000' \
       -prefix 4d.nii.gz

# assume TR doesn't matter or we need to pad 3dTcalc with blanks
#3drefit -TR 2.0 4dactive.nii.gz
