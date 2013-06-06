#!/usr/bin/env bash

set -xe

#nomot=../nomotion/pswktm_10895_nomot_roiAvg_fullFreq_1p9hold_possum_simt2_abs_trunc8_6.nii.gz
#mot=../fdM50/pswktm_10895_nomot_roiAvg_fullFreq_fdM50pct_possum_simt2_abs_trunc8_6.nii.gz
# use just before slice timing instead of p*
mni="~/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_brain_3mm.nii"
nomot=../nomotion/m_10895_nomot_roiAvg_fullFreq_1p9hold_possum_simt2_abs_trunc8.nii.gz
mot="../fdM50/m_10895_fdM50pct_roiAvg_fullFreq_SHORT_2sTR_possum_simt2_abs_trunc8.nii.gz"
#mot="../fdM50/m_10895_nomot_roiAvg_fullFreq_fdM50pct_possum_simt2_abs_trunc8.nii.gz"
roiCoord=../../buildTemplate/bb264_coordinate
# difference image, nearly a gig in size!
#[ ! -r diff.nii.gz ] && 3dcalc -overwrite -prefix diff.nii.gz -a $nomot -b $mot -expr 'a-b'
3dinfo $nomot $mot


###
# if motion is short (b/c we dont want to wait for a full simulation)
###
nomot4=$((( $(fslval $nomot dim4) -1 )))
mot4=$((( $(fslval $mot dim4)   -1 ))) 

if [ $mot4 -lt $nomot4 ];then
  newnomot=nomotion_$mot4.nii.gz
  3dTcat -overwrite -prefix $newnomot $nomot"[0..$mot4]" 
  nomot=$newnomot
fi

3dcalc -overwrite -prefix diff.nii.gz -a $nomot -b $mot -expr 'a-b'

# we have the difference in functional space
# we need the rois resampled to this space
if [ ! -r "bb264-func_resample.nii.gz" ]; then
  # roiCoord undump taken from ../../buildTemplate/createTemplate.bash
  3dUndump -overwrite -master $mni -prefix bb264-mni.nii.gz -xyz -srad 5 -orient LPI $roiCoord
  # invert func to mprage so we can move mni roi spheres into subject space
  convert_xfm -inverse ../nomotion/func_to_mprage.mat -omat mprage_to_func.mat 
  # move mni roi locations into functional space
  # to overlay on funcs that have been motion corrected
  flirt -in bb264-mni \
      -ref $nomot \
      -out bb264-func \
      -init mprage_to_func.mat -applyxfm \
      -interp nearestneighbour
  3dresample -master $nomot -inset bb264-func.nii.gz -prefix bb264-func_resample.nii.gz
  # don't trust the above, niether do I. this overlaps well though
  #flirt -in ../nomotion/pswktm_10895_nomot_roiAvg_fullFreq_1p9hold_possum_simt2_abs_trunc8_6.nii.gz \
  #    -ref $nomot \
  #    -out invert_pswktm_to_m \
  #    -init mprage_to_func.mat -applyxfm \
  #    -interp nearestneighbour
  #
fi

# SHOULD CHECK: 
  #Xvfb :9 &
  #xvfbpid=$! 
  afni -com 'SET_OVERLAY bb264-func_resample.nii.gz' -com 'SET_UNDERLAY diff.nii.gz' \
	 -com 'SAVE_JPEG A.coronalimage coronaldiff_bb264.jpg' -com 'QUIT'
  #kill $xvfbpid

# looks reasonable



3dROIstats -mask bb264-func_resample.nii.gz diff.nii.gz > ROIdiff
3dROIstats -mask bb264-func_resample.nii.gz $nomot > nomotROImean
3dROIstats -mask bb264-func_resample.nii.gz $mot   > motROImean

# generate means
# remove static intensity? -- use p* nii's
#3dcalc -a swktm_${funcFile}_${smoothing_kernel}.nii.gz -b staticIntensity_t1warp.nii.gz \
#    -expr '((a/b) - 1)*100' -prefix pswktm_${funcFile}_${smoothing_kernel}.nii.gz
