#!/bin/bash

set -e
set -x

basedir="${PWD}"
t1dir=${basedir}/mprage
t2dir=${basedir}/rest
subj=10653

#STEP 1. PREPROCESS MPRAGE - WARP TO MNI
if [ ! -f ${t1dir}/mprage_nonlinear_mni152warp_2mm.nii.gz ]; then
    echo "about to run preprocessMprage"
    cd ${t1dir}

    #new tack: use T1.mgz from freesurfer to ensure comparability with aseg file
    #then everything will be consistent through the pipeline with the same warp coefs
    #can't get things to align properly in the current 3dresample approach

#     Dimon \
# 	-infile_pattern "MR*" \
# 	-GERT_Reco \
# 	-quit \
# 	-dicom_org \
# 	-sort_by_acq_time \
# 	-gert_write_as_nifti \
# 	-gert_create_dataset \
# 	-gert_to3d_prefix mprage

#     rm -f dimon.files*
#     rm -f GERT_Reco_dicom*

#     if [ -f mprage.nii ]; then
# 	gzip -f mprage.nii #use -f to force overwrite in case where mprage.nii.gz exists, but we want to replace it.
#     fi

#     #note that this deobliques the volume, which makes it incomparable to the raw aseg
#     #thus, don't rewrite the mprage, just create an lpi version for reference (not used in warping)
#     3dresample -overwrite -orient LPI -prefix "mprage_lpi.nii.gz" -inset "mprage.nii.gz"

#     tar czf mprage_dicom.tar.gz MR* && rm -f MR*

    mri_convert /Volumes/Serena/Rest/FS_Subjects/${subj}/mri/T1.mgz \
	/Volumes/Serena/rs-fcMRI_motion_simulation/${subj}_4dtemplate/mprage/mprage.nii.gz    

    #skull strip T1
    bet mprage mprage_bet -R -f 0.5 -v

    #mprage to MNI linear warp (just for coefs). Used betted brain for template and input
    flirt -in mprage_bet -ref $HOME/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_brain_2mm \
	-omat mprage_to_mni152_affine.mat -out mprage_mni152warp_linear -v
    
    #nonlinear warp, use unbetted brain for template and input
    fnirt --ref=$HOME/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_2mm \
	--refmask=$HOME/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_mask_2mm_dil \
	--in=mprage --aff=mprage_to_mni152_affine.mat --iout=mprage_nonlinear_mni152warp_2mm \
	--config=${FSLDIR}/etc/flirtsch/T1_2_MNI152_2mm.cnf \
	--logout=fnirt_log.out -v

    #warp t1 into 1mm voxels to be used below for tissue segmentation, 
    applywarp \
	--ref=${HOME}/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c.nii \
	--in=mprage.nii.gz \
	--out=${subj}_t1_1mm_mni152 \
	--warp=mprage_warpcoef \
	--interp=sinc \
	--mask=${HOME}/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_mask.nii

    #reorient to RPI to match FSL's possum pipeline
    3dresample -orient RPI -inset ${subj}_t1_1mm_mni152.nii.gz -prefix ${subj}_t1_1mm_mni152_rpi.nii.gz

fi

cd ${basedir}

#STEP 2. Compute WM, GM, and Vent Masks from FreeSurfer aseg file
#use the warp coefficients from T1 to warp masks @ 1mm
if [ ! -f ${t1dir}/${subj}_aseg.nii.gz ]; then
    cd ${t1dir}
    echo "about to compute nuisance signals from aseg"

    #copy aseg from fs subjects dir to here
    #aseg contains codes for tissue segmentation (see 3dcalc below)
    #aseg is in native space (but manipulated some by FS)
    mri_convert /Volumes/Serena/Rest/FS_Subjects/${subj}/mri/aseg.mgz \
	/Volumes/Serena/rs-fcMRI_motion_simulation/${subj}_4dtemplate/mprage/${subj}_aseg.nii.gz

    #trim aseg to coordinates of original mprage (to make comparable for warp)
    #N.B. This step isn't working. Yields weird and large offsets
    #The aseg must have been manipulated (e.g., deobliqued) in FS
    #Change approach to use T1.mgz as structural starting point (above)
    #3dresample -inset ${subj}_aseg.nii.gz -prefix ${subj}_aseg_trimmed.nii.gz -master mprage.nii.gz
    
    #extract wm, gm, and ventricle signals from raw aseg
    3dcalc -overwrite -a ${subj}_aseg.nii.gz -expr 'amongst(a,2,7,41,46,77,78,79)' -prefix ${subj}_WM.nii.gz
    3dcalc -overwrite -a ${subj}_aseg.nii.gz -expr 'amongst(a,3,8,10,11,12,13,17,18,26,28,42,47,49,50,51,52,53,54,58,60)' -prefix ${subj}_GM.nii.gz
    3dcalc -overwrite -a ${subj}_aseg.nii.gz -expr 'amongst(a,4,5,14,15,43,44)' -prefix ${subj}_Vent.nii.gz

    #binarize masks
    fslmaths ${subj}_WM.nii.gz -bin ${subj}_WM_mask.nii.gz -odt char
    fslmaths ${subj}_GM.nii.gz -bin ${subj}_GM_mask.nii.gz -odt char
    fslmaths ${subj}_Vent.nii.gz -bin ${subj}_Vent_mask.nii.gz -odt char

    #warp masks into MNI space using same coefficients as mprage-to-mni warp
    #use nearest neighbor interpolation to avoid floating point values
    applywarp \
	--ref=${HOME}/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c.nii \
	--in=${subj}_WM_mask.nii.gz \
	--out=${subj}_WM_mask_mni \
	--warp=mprage_warpcoef \
	--interp=nn \
	--mask=${HOME}/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_mask.nii

    applywarp \
	--ref=${HOME}/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c.nii \
	--in=${subj}_GM_mask.nii.gz \
	--out=${subj}_GM_mask_mni \
	--warp=mprage_warpcoef \
	--interp=nn \
	--mask=${HOME}/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_mask.nii

    applywarp \
	--ref=${HOME}/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c.nii \
	--in=${subj}_Vent_mask.nii.gz \
	--out=${subj}_Vent_mask_mni \
	--warp=mprage_warpcoef \
	--interp=nn \
	--mask=${HOME}/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_mask.nii
    
    #erode masks (reduce possibility of partial voluming, inaccurate estimate of WM/Vent due to registration/segmentation issues)
    3dcalc -overwrite -a ${subj}_WM_mask_mni.nii.gz -b a+i -c a-i -d a+j -e a-j -f a+k -g a-k \
	-expr 'a*(1-amongst(0,b,c,d,e,f,g))' -prefix ${subj}_WM_mask_mni_erod
    3dcalc -overwrite -a ${subj}_GM_mask_mni.nii.gz -b a+i -c a-i -d a+j -e a-j -f a+k -g a-k \
	-expr 'a*(1-amongst(0,b,c,d,e,f,g))' -prefix ${subj}_GM_mask_mni_erod
    3dcalc -overwrite -a ${subj}_Vent_mask_mni.nii.gz -b a+i -c a-i -d a+j -e a-j -f a+k -g a-k \
	-expr 'a*(1-amongst(0,b,c,d,e,f,g))' -prefix ${subj}_Vent_mask_mni_erod

    3dBrickStat -count -non-zero ${subj}_WM_mask_mni.nii.gz #quick check that erosion worked
    3dBrickStat -count -non-zero ${subj}_WM_mask_mni_erod+tlrc

    3dBrickStat -count -non-zero ${subj}_Vent_mask_mni.nii.gz
    3dBrickStat -count -non-zero ${subj}_Vent_mask_mni_erod+tlrc

    #mask generation and warp complete
    #now have 3 eroded masks in MNI space for GM, WM, and Vent

fi

#STEP 3. PREPROCESS FUNCTIONAL (only through intensity normalization, no bandpass/regress
if [ ! -f ${t2dir}/nswktm_functional_6_100voxelmean.nii.gz ]; then
    cd ${t2dir}

    echo "about to preprocess functional"

    #1. motion correction
    if [ ! -f m_functional.nii.gz ]; then
	#align to middle volume (was using mean, but seems less directly interpretable in this context)
	#mcflirt -in functional -o m_functional -meanvol -stages 4 -sinc_final -rmsabs -rmsrel
	mcflirt -in functional -o m_functional -refvol 100 -stages 4 -sinc_final -rmsabs -rmsrel -plots
    fi

    #2. slice timing correction
    if [ ! -f tm_functional.nii.gz ]; then
	slicetimer -i m_functional -o tm_functional -r 1.500
    fi

    #3. warp to template

    #skull strip mean functional
    fslmaths tm_functional -Tmean tm_mean_func #generate mean functional
    bet tm_mean_func ktm_mean_func -R -f 0.4 -m #skull strip mean functional
    fslmaths tm_functional -mas ktm_mean_func_mask ktm_functional #apply skull strip mask to 4d file

    #threshold: remove for now, perhaps too non-standard
    #fslmaths "ktm_functional" -thr 123.201590 -Tmin -bin "ktm_functional_98_2_mask" -odt char #threshold low intensity voxels
    #fslmaths ktm_functional_98_2_mask -dilF ktm_functional_98_2_mask #dilate threshold mask
    #fslmaths "ktm_functional" -mas "ktm_functional_98_2_mask" "ktm_functional_masked" #apply mask to functional data

    #linear warp functional to structural
    flirt -in ktm_mean_func -ref ../mprage/mprage_bet.nii.gz -out func_to_mprage -omat func_to_mprage.mat -dof 7

    #create a dilated mask from template brain to constrain subject's warped mask
    fslmaths $HOME/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_mask_3mm.nii -dilF mni152_anatomicalmask_3mm_dil

    #warp subject mask to template space (one step warp using premat)
    applywarp \
 	--ref=$HOME/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_3mm.nii  \
 	--in=ktm_mean_func_mask \
 	--out=wktm_functional_mask \
 	--premat=func_to_mprage.mat \
 	--warp=../mprage/mprage_warpcoef.nii.gz \
 	--interp=nn \
	--mask=mni152_anatomicalmask_3mm_dil #constrains voxels roughly based on mni anatomical mask

    #warp functional into template space, masking by subject mask
    #applywarp --ref=$HOME/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_brain_3mm \
	#--in=ktm_functional --out=wktm_functional --premat=func_to_mprage.mat --warp=../mprage/mprage_warpcoef.nii.gz \
	#--interp=sinc --mask=wktm_functional_mask

    #stick with spline interpolation for now. Sinc has tendency to blur far outside the mask (as I knew),
    #but what is striking here is that any limitations of the mask are quite magnified by the sinc interpolation, but not spline
    applywarp --ref=$HOME/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_brain_3mm \
	--in=ktm_functional --out=wktm_functional --premat=func_to_mprage.mat --warp=../mprage/mprage_warpcoef.nii.gz \
	--interp=spline --mask=wktm_functional_mask

    #prior to smoothing, create and an extents mask to ensure that all time series are sampled at all timepoints
    fslmaths wktm_functional -Tmin -bin extents_mask -odt char

    #4. smoothing
    #smooth using susan (6mm FHWM= 2.547771 sigma)
    if [ ! -f swktm_functional_6.nii.gz ]; then
	fslmaths wktm_functional -Tmean wktm_mean_func
	susan wktm_functional 678.285324 2.547771 3 1 1 wktm_mean_func 678.285324 swktm_functional_6
    fi
    
    #now apply the extents mask to eliminate excessive blurring due to smooth
    fslmaths swktm_functional_6 -mul extents_mask swktm_functional_6 -odt float

    #5. intensity normalization
    #scale voxel mean to 100 (PSC)
    fslmaths swktm_functional_6 -Tmean swktm_mean_float -odt float
    fslmaths swktm_functional_6 -div swktm_mean_float -mul 100 nswktm_functional_6_100voxelmean -odt float

    #alternative, scale global mean to 1000
    fslmaths swktm_functional_6 -ing 1000 nswktm_functional_6_1000globmean -odt float

    #alternative, scale global mode to 1000
    globModeFactor=$( computeMode.R swktm_functional_6.nii.gz wktm_functional_mask.nii.gz 1000 )
    fslmaths swktm_functional_6 -mul ${globModeFactor} nswktm_functional_6_1000globmode -odt float

    #alternative, scale global median to 1000
    globMedian=$( fslstats swktm_functional_6 -P 50 )
    globMedianFactor=$( echo "scale=5; 1000/${globMedian}" | bc )
    fslmaths swktm_functional_6 -mul ${globMedianFactor} nswktm_functional_6_1000globmedian -odt float

    3drefit -TR 1.500 nswktm_functional_6_100voxelmean.nii.gz
    3drefit -TR 1.500 nswktm_functional_6_1000globmode.nii.gz
    3drefit -TR 1.500 nswktm_functional_6_1000globmean.nii.gz
    3drefit -TR 1.500 nswktm_functional_6_1000globmedian.nii.gz

fi

cd ${basedir}

####
##STEP 4: Obtain estimates of WM and Vent signal for nuisance regression
#compute WM, GM, and Ventricle signal from FreeSurfer aseg file
#need to recompute this again (relative to Kai's existing files) because of different intensity normalization

#NB: An important issue here is that the Vent and WM signals will have full frequency spectra because these have not been
#bandpassed. Thus, it's possible the Power pipeline also introduces high-frequency noise due to spectral incomparability between
#the fMRI signal and the WM and Vent regressors.

#This is solved here by computing the WM and Vent signals from nswktm data in full frequencies, but then using 3dBandpass,
#which will bandpass WM and Vent prior to regression.

if [ ! -f ${t2dir}/${subj}_nuisance_set_100voxelmean.1D ]; then
    
    cd ${t2dir}

    #not sure why de-meaning is included here (keep for now)
    1d_tool.py -overwrite -infile ${t2dir}/m_functional.par -set_nruns 1 \
        -demean -write ${t2dir}/${subj}_motion_demean.1D
     
    #compute motion parameter derivatives (for use in regression)
    1d_tool.py -overwrite -infile ${t2dir}/${subj}_motion_demean.1D -set_nruns 1 \
           -derivative -demean -write ${t2dir}/${subj}_motion_deriv.1D

    #compute nuisance set for all scalings
    for t in 100voxelmean 1000globmedian 1000globmean 1000globmode; do
	#First, we need to upsample the data to 1mm voxels to compute WM and Vent signals, as these masks are at 1mm
	if [ ! -f ${t2dir}/nswktm_functional_6_${t}_1mm.nii.gz ]; then
	    flirt -in ${t2dir}/nswktm_functional_6_${t}.nii.gz \
		-ref ${t1dir}/${subj}_t1_1mm_mni152.nii.gz \
		-applyxfm -init ${FSLDIR}/etc/flirtsch/ident.mat \
		-out ${t2dir}/nswktm_functional_6_${t}_1mm -paddingsize 0.0 -interp nearestneighbour

            #FSL is a bad little boy and strips away the TR. Bring it back!	
	    3drefit -TR 1.500 nswktm_functional_6_${t}_1mm.nii.gz
	fi

        #average voxels within preprocessed functional data
	3dmaskave -mask ${t1dir}/${subj}_WM_mask_mni_erod+tlrc -q ${t2dir}/nswktm_functional_6_${t}_1mm.nii.gz > ${subj}_WM_${t}.1D
	3dmaskave -mask ${t1dir}/${subj}_Vent_mask_mni_erod+tlrc -q ${t2dir}/nswktm_functional_6_${t}_1mm.nii.gz > ${subj}_Vent_${t}.1D
	3dmaskave -mask 'SELF' -q ${t2dir}/nswktm_functional_6_${t}_1mm.nii.gz > ${subj}_Global_${t}.1D

        #compute derivatives of wm, vent, global
	1d_tool.py -infile ${subj}_WM_${t}.1D -derivative -write ${subj}_WM_${t}_deriv.1D
	1d_tool.py -infile ${subj}_Vent_${t}.1D -derivative -write ${subj}_Vent_${t}_deriv.1D
	1d_tool.py -infile ${subj}_Global_${t}.1D -derivative -write ${subj}_Global_${t}_deriv.1D
	
        #compute set of nuisance regressors per normalization
	1dcat ${subj}_WM_${t}.1D ${subj}_Vent_${t}.1D ${subj}_Global_${t}.1D \
	    ${subj}_WM_${t}_deriv.1D ${subj}_Vent_${t}_deriv.1D ${subj}_Global_${t}_deriv.1D \
	    ${t2dir}/${subj}_motion_demean.1D ${t2dir}/${subj}_motion_demean.1D > ${t2dir}/${subj}_nuisance_set_${t}.1D
	
	1dcat ${subj}_WM_${t}.1D ${subj}_Vent_${t}.1D \
	    ${subj}_WM_${t}_deriv.1D ${subj}_Vent_${t}_deriv.1D \
	${t2dir}/${subj}_motion_demean.1D ${t2dir}/${subj}_motion_demean.1D > ${t2dir}/${subj}_nuisance_set_noglobal_${t}.1D
    done
    
fi

cd ${basedir}

#STEP 5: Bandpass filter the data and regress out nuisance signals (at once)

if [ ! -f ${t2dir}/rnswktm_functional_6_100voxelmean.nii.gz ]; then
    #only bandpass filter within brain voxels
    #need to use mask or automask effectively

    cd ${t2dir}

    #3Feb2012: Talked with Will and Kai about whether to filter the time courses input to POSSUM or keep them full spectrum
    #to be consistent with real data, we decided to keep these in full spectrum.
    #Then the output of a no-motion run of POSSUM will be preprocessed, and low-freq bandpassed, and the resulting time series will form
    #the target correlation matrix.
    #fbot=0.009
    #ftop=0.08

    #settings for "all-pass"
    fbot=0
    ftop=99999


    #Among scaling approaches, corrs among nuisance regressors are 0.97-0.99. Use 100 voxel mean for now because easier to interpret as PSC
    for t in 100voxelmean; do #OMITTING THESE FOR NOW: 1000globmedian 1000globmean 1000globmode; do
	3dBandpass -input ${t2dir}/nswktm_functional_6_${t}.nii.gz -mask extents_mask.nii.gz \
	    -prefix  ${t2dir}/rnswktm_functional_6_${t}.nii.gz -ort ${t2dir}/${subj}_nuisance_set_${t}.1D ${fbot} ${ftop}

        #retrend and scale such that baseline=1.0, scaled in terms of proportion of mean (e.g., 1.1 = 10% increase)
        #Detrending leads to a mean of 0 in all voxels (no variability across voxels), which is sensible since mean was removed
	#Non-brain voxels are at 0 already in the nswktm volumes.

        #logic: add some constant to all voxels, then determine the grand mean intensity scaling factor to achieve M = 100
	#this will make non-brain voxels 100, and voxels within the brain ~100
	#necessary to scale away from 0 to allow for division against baseline to yield PSC
	#Otherwise, leads to division by zero problems.
	fslmaths ${t2dir}/rnswktm_functional_6_${t}.nii.gz -add 100 -ing 100 rnswktm_functional_6_${t}_scaleM100 -odt float

        #dividing the M=100 file by 100 yields a proportion of mean scaling (PSC)
	fslmaths ${t2dir}/rnswktm_functional_6_${t}_scaleM100 -div 100 rnswktm_functional_6_${t}_scale1 -odt float
	
	#upsample the bandpassed data (scale 1) into 1mm voxels to match GM mask for generating 4d activation timecourse
	flirt -in ${t2dir}/rnswktm_functional_6_${t}_scale1.nii.gz \
	    -ref ${t1dir}/${subj}_t1_1mm_mni152.nii.gz \
	    -applyxfm -init ${FSLDIR}/etc/flirtsch/ident.mat \
	    -out ${t2dir}/rnswktm_functional_6_${t}_scale1_1mm -paddingsize 0.0 -interp nearestneighbour
	
        #FSL is a bad little boy and strips away the TR. Bring it back!	
	3drefit -TR 1.500 rnswktm_functional_6_${t}_scale1_1mm.nii.gz

    done

fi

cd ${basedir}

####
#separate task: generate tissue segmentation for this subject to be used as possum brain
#generate tissue segmentation for ${subj}

if [ ! -f ${t1dir}/${subj}_mni152_fast_pve_2.nii.gz ]; then
    echo "about to run fast"
    cd ${t1dir}

    #run FAST to generate tissue segmentation
    /opt/ni_tools/fsl/bin/fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 -g -o ${subj}_mni152_fast ${subj}_t1_1mm_mni152_rpi

    fslmerge -t possum_${subj}_fast ${subj}_mni152_fast_pve_1.nii.gz \
	${subj}_mni152_fast_pve_2.nii.gz \
	${subj}_mni152_fast_pve_0.nii.gz

    #ultimately, for computing time series in T2* units, will want to use linear combination of GM, WM, CSF
fi


if [ ! -f ${t2dir}/${subj}_POSSUM4D_bb244_fullFreq.nii.gz ]; then

    cd ${t1dir}

    #SETUP FOR 4d activation file
    #mask bb244 regions by gm mask
    3dUndump -overwrite -master ${subj}_t1_1mm_mni152.nii.gz -prefix bb244 -xyz -srad 5 -orient LPI bb244_coordinate

    #mask bb244 by FreeSurfer GM Mask (eroded)
    3dcalc -overwrite -a bb244+tlrc -b ${subj}_GM_mask_mni_erod+tlrc -expr 'a*b' -prefix ${subj}_bb244_gmMask_fserode

    #mask bb244 by FreeSurfer GM Mask
    3dcalc -overwrite -a bb244+tlrc -b ${subj}_GM_mask_mni.nii.gz -expr 'a*b' -prefix ${subj}_bb244_gmMask_fs

    #mask bb244 by FAST gm mask (hard classified)
    #retain each mask value
    3dcalc -overwrite -a bb244+tlrc -b ${subj}_mni152_fast_seg_1+tlrc -expr 'a*b' -prefix ${subj}_bb244_gmMask_fast
    
    #compute binary mask
    3dcalc -overwrite -a ${subj}_bb244_gmMask_fast+tlrc -expr 'step(a)' -prefix ${subj}_bb244_gmMask_fast_bin

    #apply binary bb244 FAST GM mask to final data for output for POSSUM
    3dcalc -overwrite -a ${t2dir}/rnswktm_functional_6_100voxelmean_scale1_1mm.nii.gz -b ${subj}_bb244_gmMask_fast_bin+tlrc -expr 'a*b' \
	-prefix ${t2dir}/rnswktm_functional_6_100voxelmean_scale1_1mm_244GMMask

    #scale all voxels to T2* units
    TE=29 #must match pulse!
    T2static=51

    #the equation to solve here the change in T2* relxation time (in s) relative to static T2* value
    #
    # T2*_change =   1            TE                          
    #              ____* ( ______________________     -  T2*_static )
    #              1000        TE  
    #                       _________  - ln(vox)
    #                       T2*_static

    3dcalc -a ${t2dir}/rnswktm_functional_6_100voxelmean_scale1_1mm_244GMMask+tlrc \
	-expr "((${TE}/(${TE}/${T2static}-log(a)))-${T2static})/1000" \
	-prefix ${t2dir}/${subj}_POSSUM4D_bb244_fullFreq.nii.gz

fi
exit 1


#leftovers from testing
3dROIstats -mask ${subj}_bb244_gmMask_fs+tlrc -nomeanout -nzvoxels -1DRformat bb244+tlrc > numgmVoxelsIn244ROIs_FS.1D

3dROIstats -mask ${subj}_bb244_gmMask_fast+tlrc -nomeanout -nzvoxels -1DRformat bb244+tlrc > numgmVoxelsIn244ROIs_FAST.1D

#compute correlations among 244 ROIs (just for checking/testing)
#inside mprage dir
3drefit -view orig bb244+tlrc
3drefit -view orig ${subj}_bb244_gmMask_fast+tlrc
3dcopy ${t2dir}/rnswktm_functional_6_100voxelmean_noglobal.nii.gz rr_noglob
3dcopy ${t2dir}/rnswktm_functional_6_100voxelmean.nii.gz rr
3drefit -view orig rr_noglob+tlrc
3drefit -view orig rr+tlrc

@ROI_Corr_Mat -ts rr_noglob+orig \
    -roi bb244+orig \
    -prefix ${subj}_bb244_corrmat_noglob \
    -zval 

@ROI_Corr_Mat -ts rr+orig \
    -roi bb244+orig \
    -prefix ${subj}_bb244_corrmat \
    -zval 

@ROI_Corr_Mat -ts rr_noglob+orig \
    -roi ${subj}_bb244_gmMask_fast+orig \
    -prefix ${subj}_bb244_corrmat_noglob_fast \
    -zval 

@ROI_Corr_Mat -ts rr+orig \
    -roi ${subj}_bb244_gmMask_fast+orig \
    -prefix ${subj}_bb244_corrmat_fast \
    -zval 

rm rr*
3drefit -view tlrc bb244+orig
3drefit -view tlrc ${subj}_bb244_gmMask_fast+orig
