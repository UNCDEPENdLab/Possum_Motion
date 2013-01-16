#!/bin/bash
set -x
set -e
#Goal is to check the magnitude of activation in the generated output to verify that I have the scaling broadly correct in my own 4d output.
scriptDir=$(echo $(cd $(dirname $0); pwd) )
activation3d=$scriptDir/activation3D.nii.gz
exampleSim=$scriptDir/output/possum_example_simt2_abs.nii.gz

#fslmaths $activation3d -abs -bin activationMask -odt char #some weird +/- issues in activation dataset that look like weird smoothing/interpolation artifacts
#fslmaths $activation3d -bin activationMask -odt char
#fslmaths activationMask -dilF activationMask_dil1x -odt char #dilating this mask seems to give contiguous ROIs

#alternative here: just threshold activation input at .0001, which preserves the large majority of ROIs and eliminates weird +/- banding
fslmaths $activation3d -thr .0001 activation3D_0001thresh

#obtain activation clusters/ROIs -- 1000 voxels and up (just the big ROIs)
3dmerge -overwrite -dxyz=1 -1clust_order 1 1000 -1tindex 0 -1dindex 0 -prefix activation_clustMask.nii.gz activation3D_0001thresh.nii.gz  #-1thresh 1 -1noneg

#obtain mean time series for each ROI
#first, drop 3 volumes (magnetization stabilization): timecourse begins at 8s
chop_vols=3
numVols=$( fslhd $exampleSim  | grep '^dim4' | perl -pe 's/dim4\s+(\d+)/\1/' )
fslroi $exampleSim possum_example_simt2_trunc${chop_vols} ${chop_vols} $(($numVols - 1)) #fslroi uses 0-based indexing .... actually, second param is #vols, so this math is off

fslroi brain wm_brain 1 1 #pull just the WM volume from the input brain

fslroi $exampleSim firstSimVol 0 1 #pull the first image from possum sim, which has the best contrast

#need to co-register possum output to input brain for obtaining simulated values within time series

#force 3 DOF transformation
#flirt -in firstSimVol  -ref wm_brain -out func_to_mprage -omat func_to_mprage.mat \
#    -dof 6 -schedule ${FSLDIR}/etc/flirtsch/sch3Dtrans_3dof \
#    -interp sinc -sincwidth 7 -sincwindow hanning

#more conventional 7-parameter warp
#flirt -in firstSimVol -ref wm_brain -out func_to_mprage -omat func_to_mprage.mat \
#    -dof 7 \
#    -interp sinc -sincwidth 7 -sincwindow hanning

#looks like BBR is doing a nice job here
#standard 6 parameter EPI-to-T1 registration to get initial estimate of transform                                                                                            
if [ ! -r func_to_mprage_init.mat ]; then
    flirt -in firstSimVol -ref wm_brain -out func_to_mprage -omat func_to_mprage_init.mat -dof 6
fi

if [ ! -r func_to_mprage.mat ]; then 
    #now do the BBR-based registration
    flirt -in firstSimVol -ref wm_brain -out func_to_mprage -omat func_to_mprage.mat \
	-wmseg wm_brain -cost bbr -init func_to_mprage_init.mat -dof 6 \
	-schedule ${FSLDIR}/etc/flirtsch/bbr.sch \
	-interp sinc -sincwidth 7 -sincwindow hanning
fi

#use the transformation matrix to warp all of the simulated output into the proper space
if [ $( imtest possum_example_simt2_trunc${chop_vols}_t1warp ) -eq 0 ]; then
    flirt -in possum_example_simt2_trunc${chop_vols} \
	-ref wm_brain \
	-out possum_example_simt2_trunc${chop_vols}_t1warp \
	-applyxfm -init func_to_mprage.mat \
	-interp sinc -sincwidth 7 -sincwindow hanning

    #easier just to use flirt above (note that it's slow)
    #applywarp \
	#--ref=wm_brain \
	#--in=possum_example_simt2_trunc${chop_vols} \
	#--out=possum_example_simt2_trunc${chop_vols}_t1warp \
	#--premat=func_to_mprage.mat \
	#--interp=sinc

fi

3dROIstats -mask activation_clustMask.nii.gz -1DRformat possum_example_simt2_trunc${chop_vols}_t1warp.nii.gz > activation_meanTimeCourses.1D
3dROIstats -mask activation_clustMask.nii.gz -1DRformat -median -minmax $activation3d > activation_inputVals.1D

exit 1



