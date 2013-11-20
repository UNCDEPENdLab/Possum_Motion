#!/sw/bin/bash
set -ex
## get motion like how motion was retrived for the input to possum
#
# with two arguments, work on a single file
# with no arguments, work on psm.nomo and psm.mo
#
# 
# originally used dfile from afni_proc.py (instead of preprocFunctional's mcflirt output)
# -- inputed to R as
# convertDfileToPossum.R ~/SkyDrive/Data_Analysis/rs-fcMRI_Motion/empiricalTS244/nuisancefiles/10761.dfile_WashU_3dbp.1D 10761_motion_fdM_50pct_NEW 1.5 16 

#
# see: 
#  /Volumes/Serena/rs-fcMRI_motion_simulation/Possum_Motion/defaults/motion_parameters/README
#                                                          /defaults/motion_parameters/convertDfileToPossum.R
#
# grep 3dvolreg /Volumes/Phillips/Rest/Subjects/10776/mni_AP_redo/proc.10776 -A 3
#     3dvolreg -verbose -zpad 1 -base pb03.$subj.r01.tshift+orig'[2]' \
#	-1Dfile dfile.r$run.1D -prefix pb04.$subj.r$run.volreg \
#	-cubic                                                 \
#	pb03.$subj.r$run.tshift+orig		
#

declare -A niis
if [ -z "$1" ]; then
   cd $(dirname $0)
   rm *1D
   
   niis=(                       \
        [psm.mo]="../fdM50/m_10895_fdM50pct_roiAvg_fullFreq_SHORT_2sTR_possum_simt2_abs_trunc8.nii.gz"    \
        [psm.nomo]="../nomotion/10895_nomot_roiAvg_fullFreq_1p9hold_possum_simt2_abs_trunc8.nii.gz" \
        [orig.mo]="/Volumes/Phillips/Rest/Subjects/10761/rest/1076120110519.nii.gz" \
        )

   # cut off the 16s padding added the first time (so possum doesn't flip brains)
   perl -slane '$F[0]-=16; print "@F" if $F[0]>=0' ../../defaults/motion_parameters/10761_motion_fdM_50pct_90sec46vol_2TRInterp > psm.in.1D

elif [ -n "$2" -a -r "$2" ]; then
   niis=( [$1]="$2" )
else
   cat <<HELP
   with no arguments, $(basename $0) will write 1D files to $(dirname $0) for orig.mo psm.mo and psm.nomo, and rewrite psm.in.1D in common time

   with two arguments, will write \$1.1D to $(pwd) with \$2
   ../motions/getMotion.bash largeMotion possum_example_simt2_abs.nii.gz
   # where largeMotion is what the .1D will be called
   # and possum_example_simt2_abs.nii.gz is the file to parse

   TR is 2 unless the file name matches 'orig'
HELP

fi
   
   
for n in "${!niis[@]}"; do
    TR=2
    [[ "$n" =~ "orig" ]] && TR=1.5
    # slice times 
    #3dTshift -overwrite\
    #         -tzero 0 -quintic -prefix st.nii.gz \
    #         -tpattern seq+z                     \
    #         ${niis[$n]}

    3dvolreg -overwrite -verbose -zpad 1 -base ${niis[$n]}'[2]' -1Dfile $n.3dvolreg.1D -cubic ${niis[$n]} && rm volreg*

    # put in same units as psm.in
    $(dirname $0)/../../defaults/motion_parameters/convertDfileToPossum.R $n.3dvolreg.1D $n.1D $TR 
    #writes like: c("t.x", "t.y", "t.z", "r.x", "r.y", "r.z")

done


R CMD BATCH $(dirname $0)/graph.R
