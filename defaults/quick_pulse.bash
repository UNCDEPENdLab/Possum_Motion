#!/bin/bash
scriptDir=$(echo $(cd $(dirname $0); pwd) )
pulse -i ${scriptDir}/possum_10895_fast.nii.gz -o ${scriptDir}/tr2_te30_pulse_5slc_8vol --te=0.03 --tr=2.00 \
    --trslc=0.4 --nx=60 --ny=60 --dx=0.0033 --dy=0.0033 \
    --maxG=0.055 --riset=0.00022 --bw=100000 \
    --numvol=8 --numslc=5 --slcthk=0.004 --zstart=0.040 \
    --seq=epi --slcdir=z+ --readdir=x+ \
    --phasedir=y+ --gap=0.0 -v --cover=100 --angle=90
