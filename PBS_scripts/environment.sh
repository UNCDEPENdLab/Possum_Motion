#!/usr/bin/env sh

#
# this file is intended to be sourced
#

#################
### Functions ###
#################

## test for needed variable or echo and exit
function have       { eval needed=\$$1;    [ -n "$needed" ] ; }
function exists     { eval   file=\$$1;    [ -r "$file"   ] ; }
function dircheck   { eval   dirt=\$$1;    [ -d "$dirt"   ] || mkdir -p $dirt; }

## how should we die
function die {
   echo $1 #| tee >(cat 1>&2) # hit stdout and stderr, need bash, qsub has .e and .o logs
   exit 1
}




##################
### Parameters ###
##################

#export SCRATCH="./"    # REMOVE ME

# fsl env var
export FSLOUTPUTTYPE=NIFTI_GZ

# put possum and tools in the path
PATH="$PATH:$HOME/Possum-02-2012/bin"

 VARDIR="$HOME/Possum-02-2012/variables/"
BASEDIR="$HOME/Possum-02-2012/defaults/"
#BASEDIR="/Users/michaelhallquist/Data_Analysis/rs-fcMRI_Motion/possum" #CHANGE ME! location of possum files
#BASEDIR="/Volumes/Serena/possum_speedup_tests_xsede/" # change me!

TotalCPUs=128

# runs the BlockedSize (16) jobs
scriptDir="$HOME/Possum-02-2012/PBS_scripts/"
qsubScript=$scriptDir/queuer.sh 

[ -r "$qsubScript" ] || die  "cannot open queuer $qsubScript!"

# number to run in qsub, defined by queuer
BlockedSize=$(perl -ne 'print $1 if /^#PBS\s+-l\s+ncpus=(\d+)/' $qsubScript) 
[ -n "$BlockedSize" ] || die  "missing #PBS -l ncpus!"


#
# Possum input files 
#


# files used for every run of every simulation
#       MotionFile=    <-- should be coming from parent script
#     ActivePrefix=    <-- should be coming from parent script
	    numvol=$(perl -le 'print $1 if $ENV{MotionFile} =~ /\d+_(\d+)/')
         BrainFile="${BASEDIR}/possum_10653_fast.nii.gz"
         PulseFile="${BASEDIR}/pulse_$numvol" 			#*** PULSE is pulse_numvols -- determin from MotionFile
            RFFile="${BASEDIR}/slcprof"
            MRFile="${BASEDIR}/MRpar_3T"
    ActivationFile="${VARDIR}/${ActivePrefix}.nii.gz"
ActivationTimeFile="${VARDIR}/${ActivePrefix}_time"



