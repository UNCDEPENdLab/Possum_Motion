#!/usr/bin/env sh

#
# this file is intended to be sourced
#
# provides definition of directories
#
# simID should already be exported
#

[ -n "$simID" ] || die "no simID!"

SimOutDir="$SCRATCH/sim/$simID"
simOutDir="$SCRATCH/sim/$simID"
   LogDir="$SimOutDir/logs"

