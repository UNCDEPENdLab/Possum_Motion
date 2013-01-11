#!/bin/bash

# Last modified, WF 2012-09-06, finalOutput=${t2dir}/${sid}_POSSUM4D_bb264AVG_fullFreq.nii.gz
 
#######
# Create template for possum active4d input
# $0 -sid 10875 -sdir ./ -t1 T1.mgz -aseg aseg.mgz -t2 functional.nii.gz  -roi bb264_coordinate
# require -t2 -sdir and -sid
# outputs in sdir/{mprage,rest}
# OPTIONS:
#END#

set -e

# TODO: set via fslhd or 3dinfo
#Defaults
TR=2.000
#scale all voxels to T2* units
TE=30 #must match pulse for simulation!
T2static=51

while [ -n "$1" ]; do
 case $1 in 
  -sdir)      sdir=$2;        shift 2;;  # subject's folder -- where to save mprage/ and rest/
  -sid)       sid=$2;         shift 2;;  # subject id       -- where to find FS stuff, what to prefix files
  -t1)        t1=$2;          shift 2;;  # t1 image, mgz format (/Volumes/Serena/Rest/FS_Subjects/${sid}/mri/T1.mgz)
  -aseg)      aseg=$2;        shift 2;;  # FS segmentation, mgz format (/Volumes/Serena/Rest/FS_Subjects/${sid}/mri/aseg.mgz) 
  -t2)        t2=$2;          shift 2;;  # functional image, nii format
  -roi)       roiCoord=$2;    shift 2;;  # roi coordinate file, LPI mni x y z (/Volumes/Serena/rs-fcMRI_motion_simulation/bb264_coordinate)
  -tr)        TR=$2;          shift 2;;  # TR of resting state scan (default 2)
  -te)        TE=$2;          shift 2;;  # TE of possum functional, must match pulse (29)
  -t2static)  T2static=$2;    shift 2;;  # used to calculate units for possum (51)
  *) echo -e "[Unrecognized option '$1']"; 
     sed -ne "s:\$0:$0:g;s/# //p;/END/q" $0;                             # print header
     perl -lne 'print "\t$1:\t$2" if m/^\s+(-.*)\).*shift.*# (.*)$/' $0; # print options
     echo ;
     exit 1;;
 esac
done

#get absolute path of script directory since mni_refs is relative to that
scriptDir=$(echo $(cd $(dirname $0); pwd) )
#echo "$scriptDir"

mniref_1mm=$scriptDir/mni_refs/mni_icbm152_t1_tal_nlin_asym_09c
mniref_1mm_mask=$scriptDir/mni_refs/mni_icbm152_t1_tal_nlin_asym_09c_mask
mniref_2mm=$scriptDir/mni_refs/mni_icbm152_t1_tal_nlin_asym_09c_2mm
mniref_2mm_brain=$scriptDir/mni_refs/mni_icbm152_t1_tal_nlin_asym_09c_brain_2mm
mniref_2mm_dilmask=$scriptDir/mni_refs/mni_icbm152_t1_tal_nlin_asym_09c_mask_2mm_dil
mniref_3mm=$scriptDir/mni_refs/mni_icbm152_t1_tal_nlin_asym_09c_3mm
mniref_3mm_mask=$scriptDir/mni_refs/mni_icbm152_t1_tal_nlin_asym_09c_mask_3mm
fnirtConf=$scriptDir/mni_refs/T1_2_MNI152_2mm.cnf

source avgValuesWithinROIs.bash

# check and/or set defaults
[ -z "$sdir" ] && echo "Requires -sdir" && exit 1
[ -z "$sid"  ] && echo "Requires -sid"  && exit 1
[ -z "$t1" ]   && echo "Requires -t1"   && exit 1  #t1=/Volumes/Serena/Rest/FS_Subjects/${sid}/mri/T1.mgz
[ -z "$t2" ]   && echo "Requires -t2"   && exit 1
[ -z "$aseg" ] && echo "Requires -aseg" && exit 1  #aseg=/Volumes/Serena/Rest/FS_Subjects/${sid}/mri/aseg.mgz
[ -z "$roiCoord" ] && echo "Requires -roiCoord in LPI orientation" && exit 1  #roiCoord=/Volumes/Serena/rs-fcMRI_motion_simulation/bb264_coordinate

for varname in sdir t1 t2 aseg roiCoord; do
  # make absolute path
  printf -v $varname "$(cd $(dirname ${!varname}); pwd)/$(basename ${!varname})"
  # don't need to be able to read sdir, we will make it
  [ "$varname" = "sdir" ] && continue
  # check for file
  [ ! -r ${!varname} ] && echo "could not read $varname (${!varname}), exiting" && exit 1;
done
###

#check for the existence of t1 and t2 dirs. create if needed
t1dir=${sdir}/mprage
t2dir=${sdir}/rest
for dir in $t1dir $t2dir; do
 [ ! -d $dir ] && mkdir -p $dir
done

t2base=$( remove_ext $( basename "$t2" ) )

set -x

#STEP 1. PREPROCESS MPRAGE - WARP TO MNI
if [ ! -f ${t1dir}/${sid}_t1_2mm_mni152.nii.gz ]; then
    echo "About to preprocess mprage"
    cd ${t1dir}

    #new tack: use T1.mgz from freesurfer to ensure comparability with aseg file
    #then everything will be consistent through the pipeline with the same warp coefs
    #can't get things to align properly in the current 3dresample approach

    mri_convert $t1 ${t1dir}/${sid}_mprage.nii.gz    

    #skull strip T1
    bet ${sid}_mprage ${sid}_mprage_bet -R -f 0.5 -v

    #mprage to MNI linear warp (just for coefs). Used betted brain for template and input
    flirt -in ${sid}_mprage_bet -ref $mniref_2mm_brain \
	-omat ${sid}_mprage_to_mni152_affine.mat -out ${sid}_mprage_mni152warp_linear -v
    
    #nonlinear warp, use unbetted brain for template and input
    fnirt --ref=$mniref_2mm \
	--refmask=$mniref_2mm_dilmask \
	--in=${sid}_mprage --aff=${sid}_mprage_to_mni152_affine.mat \
	--iout=${sid}_t1_2mm_mni152 \
	--cout=${sid}_mprage_warpcoef \
	--interp=spline \
	--config=$fnirtConf \
	--logout=fnirt_log.out -v

    #warp t1 into 1mm voxels to be used below for tissue segmentation
    applywarp \
	--ref=$mniref_1mm \
	--in=${sid}_mprage \
	--out=${sid}_t1_1mm_mni152 \
	--warp=${sid}_mprage_warpcoef \
	--interp=sinc \
	--mask=$mniref_1mm_mask

    #reorient to RPI to match FSL's possum pipeline
    3dresample -orient RPI -inset ${sid}_t1_1mm_mni152.nii.gz -prefix ${sid}_t1_1mm_mni152_rpi.nii.gz

    #there are a few high-intensity voxels from the freesurfer T1 that are non-brain tissue, but manifest as sharp white voxels in the processed T1
    #get rid of these using an upper threshold of 240 (values run from 0-255)
    fslmaths ${sid}_t1_1mm_mni152 -uthr 240 ${sid}_t1_1mm_mni152
    fslmaths ${sid}_t1_1mm_mni152_rpi -uthr 240 ${sid}_t1_1mm_mni152_rpi
    fslmaths ${sid}_t1_2mm_mni152 -uthr 240 ${sid}_t1_2mm_mni152

fi

cd ${basedir}

#STEP 2. Compute WM, GM, and Vent Masks from FreeSurfer aseg file
#use the warp coefficients from T1 to warp masks @ 1mm
if [ ! -f ${t1dir}/${sid}_aseg.nii.gz ]; then
    cd ${t1dir}
    echo "about to compute nuisance signals from aseg"

    #copy aseg from fs subjects dir to here
    #aseg contains codes for tissue segmentation (see 3dcalc below)
    #aseg is in native space (but manipulated some by FS)
    mri_convert $aseg $t1dir/${sid}_aseg.nii.gz
    
    #extract wm, gm, and ventricle signals from raw aseg
    3dcalc -overwrite -a ${sid}_aseg.nii.gz -expr 'amongst(a,2,7,41,46,77,78,79)' -prefix ${sid}_WM.nii.gz
    3dcalc -overwrite -a ${sid}_aseg.nii.gz -expr 'amongst(a,3,8,10,11,12,13,17,18,26,28,42,47,49,50,51,52,53,54,58,60)' -prefix ${sid}_GM.nii.gz
    3dcalc -overwrite -a ${sid}_aseg.nii.gz -expr 'amongst(a,4,5,14,15,43,44)' -prefix ${sid}_Vent.nii.gz

    #binarize masks
    fslmaths ${sid}_WM.nii.gz -bin ${sid}_WM_mask.nii.gz -odt char
    fslmaths ${sid}_GM.nii.gz -bin ${sid}_GM_mask.nii.gz -odt char
    fslmaths ${sid}_Vent.nii.gz -bin ${sid}_Vent_mask.nii.gz -odt char

    #warp masks into MNI space using same coefficients as mprage-to-mni warp
    #use nearest neighbor interpolation to avoid floating point values
    applywarp \
	--ref=$mniref_1mm \
	--in=${sid}_WM_mask \
	--out=${sid}_WM_mask_mni \
	--warp=${sid}_mprage_warpcoef \
	--interp=nn \
	--mask=$mniref_1mm_mask

    applywarp \
	--ref=$mniref_1mm \
	--in=${sid}_GM_mask \
	--out=${sid}_GM_mask_mni \
	--warp=${sid}_mprage_warpcoef \
	--interp=nn \
	--mask=$mniref_1mm_mask

    applywarp \
	--ref=$mniref_1mm \
	--in=${sid}_Vent_mask \
	--out=${sid}_Vent_mask_mni \
	--warp=${sid}_mprage_warpcoef \
	--interp=nn \
	--mask=$mniref_1mm_mask
    
    #erode masks (reduce possibility of partial voluming, inaccurate estimate of WM/Vent due to registration/segmentation issues)
    3dcalc -overwrite -a ${sid}_WM_mask_mni.nii.gz -b a+i -c a-i -d a+j -e a-j -f a+k -g a-k \
	-expr 'a*(1-amongst(0,b,c,d,e,f,g))' -prefix ${sid}_WM_mask_mni_erod
    3dcalc -overwrite -a ${sid}_GM_mask_mni.nii.gz -b a+i -c a-i -d a+j -e a-j -f a+k -g a-k \
	-expr 'a*(1-amongst(0,b,c,d,e,f,g))' -prefix ${sid}_GM_mask_mni_erod
    3dcalc -overwrite -a ${sid}_Vent_mask_mni.nii.gz -b a+i -c a-i -d a+j -e a-j -f a+k -g a-k \
	-expr 'a*(1-amongst(0,b,c,d,e,f,g))' -prefix ${sid}_Vent_mask_mni_erod

    3dBrickStat -count -non-zero ${sid}_WM_mask_mni.nii.gz #quick check that erosion worked
    3dBrickStat -count -non-zero ${sid}_WM_mask_mni_erod+tlrc

    3dBrickStat -count -non-zero ${sid}_Vent_mask_mni.nii.gz
    3dBrickStat -count -non-zero ${sid}_Vent_mask_mni_erod+tlrc

    #mask generation and warp complete
    #now have 3 eroded masks in MNI space for GM, WM, and Vent

fi

#STEP 3. PREPROCESS FUNCTIONAL (only through intensity normalization, no bandpass/regress
if [ ! -f ${t2dir}/nswktm_${t2base}_6_100voxelmean.nii.gz ]; then
    cd ${t2dir}

    echo "about to preprocess functional"

    #1. motion correction
    if [ $( imtest m_${t2base} ) -eq 0 ]; then
	#align to middle volume (was using mean, but seems less directly interpretable in this context)
	#mcflirt -in functional -o m_functional -meanvol -stages 4 -sinc_final -rmsabs -rmsrel
	mcflirt -in $t2 -o m_${t2base} -refvol 75 -stages 4 -sinc_final -rmsabs -rmsrel -plots #assumes 150 TRs
    fi

    #2. slice timing correction, assumes interleaved, which matches cogemo
    if [ $( imtest tm_${t2base} ) -eq 0 ]; then
	slicetimer -i m_${t2base} -o tm_${t2base} -r $TR --odd
    fi

    #skull strip mean functional
    if [ $( imtest ktm_${t2base} ) -eq 0 ]; then
	fslmaths tm_${t2base} -Tmean tm_mean_func #generate mean functional
	bet tm_mean_func ktm_mean_func -R -f 0.3 -m #skull strip mean functional
	fslmaths tm_${t2base} -mas ktm_mean_func_mask ktm_${t2base} #apply skull strip mask to 4d file
    fi

    p_2=$( fslstats ktm_${t2base} -p 2 ) #2nd percentile of skull-stripped image
    p_98=$( fslstats ktm_${t2base} -p 98 ) #98th percentils of skull-stripped image

    #note that this threshold calculation is based on FEAT's brain/background threshold of 10                                                                                       
    #the FEAT calculation is p2 + (brain_thresh * (p98 -p2))/100. When brain_thresh is 10, cancels a zero.                                                                               
    thresh=$( echo "scale=5; $p_2 + ($p_98 - $p_2)/10" | bc )

    if [ $( imtest ktm_${t2base}_masked ) -eq 0 ]; then
	
        #create mask that zeroes anything below threshold.
        #because this mask is computed on the skull-stripped data, it also reflects skull stripping
	fslmaths ktm_${t2base} -thr $thresh -Tmin -bin ktm_${t2base}_98_2_mask -odt char

        #dilate 98_2 mask to reduce likelihood of removing brain voxels
	fslmaths ktm_${t2base}_98_2_mask -dilF ktm_${t2base}_98_2_mask_dil1x

        #apply mask (that includes skull stripping)
	fslmaths tm_${t2base} -mas ktm_${t2base}_98_2_mask_dil1x ktm_${t2base}_masked

    fi

    median_intensity=$( fslstats tm_${t2base} -k ktm_${t2base}_98_2_mask -p 50 )

    #compute epi-to-structural transformation
    if [ $( imtest ${t1dir}/${sid}_mprage_bet_fast_wmseg ) -eq 0 ]; then
	echo "Using boundary-based registration approach to register EPI to T1"
	fast -o ${t1dir}/${sid}_mprage_bet_fast ${t1dir}/${sid}_mprage_bet #segment T1 to create WM mask
	fslmaths ${t1dir}/${sid}_mprage_bet_fast_pve_2 -thr 0.5 -bin ${t1dir}/${sid}_mprage_bet_fast_wmseg #create binary WM mask 

        #standard 6 parameter EPI-to-T1 registration to get initial estimate of transform                                                                                            
	flirt -in ktm_mean_func -ref ${t1dir}/${sid}_mprage_bet -out func_to_mprage -omat func_to_mprage_init.mat -dof 6
	
        #now do the BBR-based registration                                                                                                                                           
        #N.B.: the epi_reg program uses betted T1 for initial transformation, but the unbetted image for BBR registration!

	flirt -in ktm_mean_func -ref ${t1dir}/${sid}_mprage_bet -out func_to_mprage -omat func_to_mprage.mat \
	    -wmseg ${t1dir}/${sid}_mprage_bet_fast_wmseg -cost bbr -init func_to_mprage_init.mat -dof 6 \
	    -schedule ${FSLDIR}/etc/flirtsch/bbr.sch	
    fi


    if [ $( imtest wktm_${t2base} ) -eq 0 ]; then
        #create a dilated mask from template brain to constrain subject's warped mask
	fslmaths $mniref_3mm_mask -dilF mni152_anatomicalmask_3mm_dil

        #3. warp to template
        #warp subject mask to template space (one step warp using premat)
	applywarp \
 	    --ref=$mniref_3mm \
 	    --in=ktm_mean_func_mask \
 	    --out=wktm_functional_mask \
 	    --premat=func_to_mprage.mat \
 	    --warp=${t1dir}/${sid}_mprage_warpcoef \
 	    --interp=nn \
	    --mask=mni152_anatomicalmask_3mm_dil #constrains voxels roughly based on mni anatomical mask

        #warp functional into template space, masking by subject mask
        #applywarp --ref=$HOME/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_brain_3mm \
	    #--in=ktm_functional --out=wktm_functional --premat=func_to_mprage.mat --warp=../mprage/mprage_warpcoef.nii.gz \
     	    #--interp=sinc --mask=wktm_functional_mask

        #stick with spline interpolation for now. Sinc has tendency to blur far outside the mask (as I knew),
        #but what is striking here is that any limitations of the mask are quite magnified by the sinc interpolation, but not spline
	applywarp --ref=$mniref_3mm \
	    --in=ktm_${t2base}_masked --out=wktm_${t2base} --premat=func_to_mprage.mat --warp=${t1dir}/${sid}_mprage_warpcoef \
	    --interp=spline --mask=wktm_functional_mask

    fi

    #4. smoothing
    #smooth using susan (6mm FHWM= 2.547771 sigma)
    if [ $( imtest swktm_${t2base}_6 ) -eq 0 ]; then
        #prior to smoothing, create and an extents mask to ensure that all time series are sampled at all timepoints
	fslmaths wktm_${t2base} -Tmin -bin extents_mask -odt char


	susan_int=$( echo "scale=5; ($median_intensity - $p_2)*.75" | bc )
	fslmaths wktm_${t2base} -Tmean wktm_mean_func
	susan wktm_${t2base} $susan_int 2.547771 3 1 1 wktm_mean_func $susan_int swktm_${t2base}_6

        #now apply the extents mask to eliminate excessive blurring due to smooth
        fslmaths swktm_${t2base}_6 -mas extents_mask swktm_${t2base}_6 -odt float
    fi

    #5. intensity normalization
    #scale voxel mean to 100 (PSC)
    fslmaths swktm_${t2base}_6 -Tmean swktm_mean_float -odt float #get temporal mean of smoothed data
    
    #divide each voxel time series by the mean, then multiply by 100
    fslmaths swktm_${t2base}_6 -div swktm_mean_float -mul 100 nswktm_${t2base}_6_100voxelmean -odt float

    #alternative, scale global mean to 1000
    #fslmaths swktm_${t2base}_6 -ing 1000 nswktm_${t2base}_6_1000globmean -odt float

    #alternative, scale global mode to 1000
    #computeMode=$scriptDir/computeMode.R 
    #globModeFactor=$($computeMode swktm_${t2base}_6.nii.gz wktm_${t2base}_mask.nii.gz 1000 )
    #3dcalc -overwrite -a swktm_${t2base}_6.nii.gz -exp "a*${globModeFactor}" -prefix nswktm_${t2base}_6_1000globmode.nii.gz

    #alternative, scale global median to 1000
    #globMedian=$( fslstats swktm_${t2base}_6 -P 50 )
    #globMedianFactor=$( echo "scale=5; 1000/${globMedian}" | bc )
    #fslmaths swktm_${t2base}_6 -mul ${globMedianFactor} nswktm_${t2base}_6_1000globmedian -odt float

    #ensure that TR is properly preserved
    for suffix in 100voxelmean; do # 1000globmode 1000globmean 1000globmedian; do
       3drefit -TR $TR nswktm_${t2base}_6_${suffix}.nii.gz
    done

    #cleanup
    imrm extents_mask swktm_mean_float wktm_mean_func tm_mean_func mni152_anatomicalmask_3mm_dil swktm_${t2base}_6_usan_size
    rm -rf m_${t2base}.mat m_${t2base}_abs_mean.rms m_${t2base}_rel_mean.rms

fi

####
##STEP 4: Obtain estimates of WM and Vent signal for nuisance regression
#compute WM, GM, and Ventricle signal from FreeSurfer aseg file

#NB: An important issue here is that the Vent and WM signals will have full frequency spectra because these have not been
#bandpassed yet. Thus, it's possible the Power pipeline also introduces high-frequency noise due to spectral incomparability between
#the fMRI signal and the WM and Vent regressors.

#This is solved here by computing the WM and Vent signals from nswktm data in full frequencies, but then using 3dBandpass,
#which will bandpass WM and Vent prior to regression.

if [ ! -f ${t2dir}/nuisance_regressors/${sid}_nuisance_set_100voxelmean.1D ]; then
    
    cd ${t2dir}

    [ ! -d nuisance_regressors ] && mkdir nuisance_regressors

    #not sure why de-meaning is included here (keep for now)
    1d_tool.py -overwrite -infile ${t2dir}/m_${t2base}.par -set_nruns 1 \
        -demean -write ${t2dir}/nuisance_regressors/${sid}_motion_demean.1D
     
    #compute motion parameter derivatives (for use in regression)
    1d_tool.py -overwrite -infile ${t2dir}/nuisance_regressors/${sid}_motion_demean.1D -set_nruns 1 \
           -derivative -demean -write ${t2dir}/nuisance_regressors/${sid}_motion_deriv.1D

    #compute nuisance set for all scalings
    for t in 100voxelmean 1000globmedian 1000globmean 1000globmode; do
	#First, we need to upsample the data to 1mm voxels to compute WM and Vent signals, as these masks are at 1mm
	if [ ! -f ${t2dir}/nswktm_${t2base}_6_${t}_1mm.nii.gz ]; then
	    flirt -in ${t2dir}/nswktm_${t2base}_6_${t}.nii.gz \
		-ref ${t1dir}/${sid}_t1_1mm_mni152.nii.gz \
		-applyxfm -init ${FSLDIR}/etc/flirtsch/ident.mat \
		-out ${t2dir}/nswktm_${t2base}_6_${t}_1mm -paddingsize 0.0 -interp nearestneighbour

            #FSL is a bad little boy and strips away the TR. Bring it back!	
	    3drefit -TR $TR nswktm_${t2base}_6_${t}_1mm.nii.gz
	fi

        #average voxels within preprocessed functional data
	3dmaskave -mask ${t1dir}/${sid}_WM_mask_mni_erod+tlrc -q ${t2dir}/nswktm_${t2base}_6_${t}_1mm.nii.gz > ${t2dir}/nuisance_regressors/${sid}_WM_${t}.1D
	3dmaskave -mask ${t1dir}/${sid}_Vent_mask_mni_erod+tlrc -q ${t2dir}/nswktm_${t2base}_6_${t}_1mm.nii.gz > ${t2dir}/nuisance_regressors/${sid}_Vent_${t}.1D
	3dmaskave -mask 'SELF' -q ${t2dir}/nswktm_${t2base}_6_${t}_1mm.nii.gz > ${t2dir}/nuisance_regressors/${sid}_Global_${t}.1D

        #compute derivatives of wm, vent, global
	1d_tool.py -overwrite -infile ${t2dir}/nuisance_regressors/${sid}_WM_${t}.1D -derivative -write ${t2dir}/nuisance_regressors/${sid}_WM_${t}_deriv.1D
	1d_tool.py -overwrite -infile ${t2dir}/nuisance_regressors/${sid}_Vent_${t}.1D -derivative -write ${t2dir}/nuisance_regressors/${sid}_Vent_${t}_deriv.1D
	1d_tool.py -overwrite -infile ${t2dir}/nuisance_regressors/${sid}_Global_${t}.1D -derivative -write ${t2dir}/nuisance_regressors/${sid}_Global_${t}_deriv.1D
	
        #compute set of nuisance regressors per normalization
	1dcat -overwrite ${t2dir}/nuisance_regressors/${sid}_WM_${t}.1D \
	    ${t2dir}/nuisance_regressors/${sid}_Vent_${t}.1D \
	    ${t2dir}/nuisance_regressors/${sid}_Global_${t}.1D \
	    ${t2dir}/nuisance_regressors/${sid}_WM_${t}_deriv.1D \
	    ${t2dir}/nuisance_regressors/${sid}_Vent_${t}_deriv.1D \
	    ${t2dir}/nuisance_regressors/${sid}_Global_${t}_deriv.1D \
	    ${t2dir}/nuisance_regressors/${sid}_motion_demean.1D \
	    ${t2dir}/nuisance_regressors/${sid}_motion_deriv.1D > ${t2dir}/nuisance_regressors/${sid}_nuisance_set_${t}.1D

	1dcat -overwrite ${t2dir}/nuisance_regressors/${sid}_WM_${t}.1D \
	    ${t2dir}/nuisance_regressors/${sid}_Vent_${t}.1D \
	    ${t2dir}/nuisance_regressors/${sid}_WM_${t}_deriv.1D \
	    ${t2dir}/nuisance_regressors/${sid}_Vent_${t}_deriv.1D \
	    ${t2dir}/nuisance_regressors/${sid}_motion_demean.1D \
	    ${t2dir}/nuisance_regressors/${sid}_motion_deriv.1D > ${t2dir}/nuisance_regressors/${sid}_nuisance_set_noglobal_${t}.1D
    done
    
fi

cd ${basedir}

#STEP 5: Bandpass filter the data and regress out nuisance signals (at once)

if [ $( imtest ${t2dir}/brnswktm_${t2base}_6_100voxelmean ) -eq 0 ]; then
    #only bandpass filter within brain voxels
    #need to use mask or automask effectively

    cd ${t2dir}

    #3Feb2012: Talked with Will and Kai about whether to filter the time courses input to POSSUM or keep them full spectrum
    #to be consistent with real data, we decided to keep these in full spectrum.
    #Then the output of a no-motion run of POSSUM will be preprocessed, and low-freq bandpassed, and the resulting time series will form
    #the target correlation matrix.

    #now creating outputs for both bandpass-filtered + regressed data (using 3dBandpass) and regression alone (3dDetrend)

    fbot=0.009
    ftop=0.08

    #settings for "all-pass"
    #fbot=0
    #ftop=99999

    #Among scaling approaches, corrs among nuisance regressors are 0.97-0.99. Use 100 voxel mean for now because easier to interpret as PSC
    for t in 100voxelmean; do #OMITTING THESE FOR NOW: 1000globmedian 1000globmean 1000globmode; do
	3dBandpass -input ${t2dir}/nswktm_${t2base}_6_${t}.nii.gz -mask ${t2dir}/wktm_functional_mask.nii.gz \
	    -prefix ${t2dir}/brnswktm_${t2base}_6_${t}.nii.gz -ort ${t2dir}/nuisance_regressors/${sid}_nuisance_set_noglobal_${t}.1D ${fbot} ${ftop}

	#use 3dDetrend to regress out nuisance signals without bandpass
	3dDetrend -verb -polort 2 -vector ${t2dir}/nuisance_regressors/${sid}_nuisance_set_noglobal_${t}.1D \
	    -prefix ${t2dir}/rnswktm_${t2base}_6_${t}.nii.gz ${t2dir}/nswktm_${t2base}_6_${t}.nii.gz

	#as with 3dBandpass, ensure that result of detrending is masked by brain
	fslmaths ${t2dir}/rnswktm_${t2base}_6_${t}.nii.gz -mas ${t2dir}/wktm_functional_mask.nii.gz ${t2dir}/rnswktm_${t2base}_6_${t}.nii.gz 

        #retrend and scale such that baseline=1.0, scaled in terms of proportion of mean (e.g., 1.1 = 10% increase)
        #Detrending leads to a mean of 0 in all voxels (no variability across voxels), which is sensible since mean was removed
	#Non-brain voxels are at 0 already in the nswktm volumes.

        #logic: add some constant to all voxels, then determine the grand mean intensity scaling factor to achieve M = 100
	#this will make non-brain voxels 100, and voxels within the brain ~100
	#necessary to scale away from 0 to allow for division against baseline to yield PSC
	#Otherwise, leads to division by zero problems.
	fslmaths ${t2dir}/brnswktm_${t2base}_6_${t}.nii.gz -add 100 -ing 100 brnswktm_${t2base}_6_${t}_scaleM100 -odt float
	fslmaths ${t2dir}/rnswktm_${t2base}_6_${t}.nii.gz -add 100 -ing 100 rnswktm_${t2base}_6_${t}_scaleM100 -odt float

        #dividing the M=100 file by 100 yields a proportion of mean scaling (PSC)
	fslmaths ${t2dir}/brnswktm_${t2base}_6_${t}_scaleM100 -div 100 brnswktm_${t2base}_6_${t}_scale1 -odt float
	fslmaths ${t2dir}/rnswktm_${t2base}_6_${t}_scaleM100 -div 100 rnswktm_${t2base}_6_${t}_scale1 -odt float
	
	#upsample the bandpassed data (scale 1) into 1mm voxels to match GM mask for generating 4d activation timecourse
	flirt -in ${t2dir}/brnswktm_${t2base}_6_${t}_scale1 \
	    -ref ${t1dir}/${sid}_t1_1mm_mni152 \
	    -applyxfm -init ${FSLDIR}/etc/flirtsch/ident.mat \
	    -out ${t2dir}/brnswktm_${t2base}_6_${t}_scale1_1mm -paddingsize 0.0 -interp nearestneighbour

	flirt -in ${t2dir}/rnswktm_${t2base}_6_${t}_scale1 \
	    -ref ${t1dir}/${sid}_t1_1mm_mni152 \
	    -applyxfm -init ${FSLDIR}/etc/flirtsch/ident.mat \
	    -out ${t2dir}/rnswktm_${t2base}_6_${t}_scale1_1mm -paddingsize 0.0 -interp nearestneighbour

        #FSL is a bad little boy and strips away the TR. Bring it back!	
	#3drefit -TR $TR rnswktm_${t2base}_6_${t}_scale1_1mm.nii.gz

    done

fi

cd ${basedir}

####
#separate task: generate tissue segmentation for this subject to be used as possum brain
#generate tissue segmentation for ${sidj}

if [ ! -f ${t1dir}/${sid}_mni152_fast_pve_2.nii.gz ]; then
    echo "about to run fast"
    cd ${t1dir}

    #run FAST to generate tissue segmentation
    fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 -g -o ${sid}_mni152_fast ${sid}_t1_1mm_mni152_rpi

    fslmerge -t possum_${sid}_fast ${sid}_mni152_fast_pve_1.nii.gz \
	${sid}_mni152_fast_pve_2.nii.gz \
	${sid}_mni152_fast_pve_0.nii.gz

    #ultimately, for computing time series in T2* units, will want to use linear combination of GM, WM, CSF
fi

finalOutput=${t2dir}/${sid}_POSSUM4D_bb264_roiAvg_fullFreq.nii.gz
if [ ! -f $finalOutput ]; then

    cd ${t1dir}

    #SETUP FOR 4d activation file
    #mask bb264 regions by gm mask
    #generate 5mm radius spheres around 264 coordinates
    3dUndump -overwrite -master ${sid}_t1_1mm_mni152.nii.gz -prefix bb264 -xyz -srad 5 -orient LPI $roiCoord

    #mask bb264 by FreeSurfer GM Mask (eroded)
    3dcalc -overwrite -a bb264+tlrc -b ${sid}_GM_mask_mni_erod+tlrc -expr 'a*b' -prefix ${sid}_bb264_gmMask_fserode

    #mask bb264 by FreeSurfer GM Mask
    3dcalc -overwrite -a bb264+tlrc -b ${sid}_GM_mask_mni.nii.gz -expr 'a*b' -prefix ${sid}_bb264_gmMask_fs

    #mask bb264 by FAST gm mask (hard classified)
    #retain each mask value
    3dcalc -overwrite -a bb264+tlrc -b ${sid}_mni152_fast_seg_1.nii.gz -expr 'a*b' -prefix ${sid}_bb264_gmMask_fast
    
    #compute binary mask of gray matter
    3dcalc -overwrite -a ${sid}_bb264_gmMask_fast+tlrc -expr 'step(a)' -prefix ${sid}_bb264_gmMask_fast_bin

    cd ${t2dir}

    #apply binary bb264 FAST GM mask to final data for output for POSSUM
    [ ! -r ${t2dir}/rnswktm_${t2base}_6_100voxelmean_scale1_1mm_264GMMask+tlrc.HEAD ] && \
	3dcalc -overwrite -a ${t2dir}/rnswktm_${t2base}_6_100voxelmean_scale1_1mm.nii.gz -b ${sid}_bb264_gmMask_fast_bin+tlrc -expr 'a*b' \
	-prefix ${t2dir}/rnswktm_${t2base}_6_100voxelmean_scale1_1mm_264GMMask

    [ ! -r ${t2dir}/brnswktm_${t2base}_6_100voxelmean_scale1_1mm_264GMMask+tlrc.HEAD ] && \
	3dcalc -overwrite -a ${t2dir}/brnswktm_${t2base}_6_100voxelmean_scale1_1mm.nii.gz -b ${sid}_bb264_gmMask_fast_bin+tlrc -expr 'a*b' \
	-prefix ${t2dir}/brnswktm_${t2base}_6_100voxelmean_scale1_1mm_264GMMask

    #COMPUTE AVERAGE ACTIVATION WITHIN EACH ROI
    [ ! -r ${t2dir}/rnswktm_${t2base}_6_100voxelmean_scale1_1mm_264GMMask_roiMean.nii.gz ] && \
	avgValWiROIs ${t2dir}/rnswktm_${t2base}_6_100voxelmean_scale1_1mm_264GMMask+tlrc

    [ ! -r ${t2dir}/brnswktm_${t2base}_6_100voxelmean_scale1_1mm_264GMMask_roiMean.nii.gz ] && \
	avgValWiROIs ${t2dir}/brnswktm_${t2base}_6_100voxelmean_scale1_1mm_264GMMask+tlrc

    # T2static and TE defined above
    # makes 
    #the equation to solve here the change in T2* relxation time (in s) relative to static T2* value
    #
    # T2*_change =   1            TE                          
    #              ____* ( ______________________     -  T2*_static )
    #              1000        TE  
    #                       _________  - ln(vox)
    #                       T2*_static

    #final input for full frequency, ROIs averaged
    3dcalc -a ${t2dir}/rnswktm_${t2base}_6_100voxelmean_scale1_1mm_264GMMask_roiMean.nii.gz \
	-expr "((${TE}/(${TE}/${T2static}-log(a)))-${T2static})/1000" \
	-prefix $finalOutput 

    #final input for bandpass filtered data, ROIs averaged
    3dcalc -a ${t2dir}/brnswktm_${t2base}_6_100voxelmean_scale1_1mm_264GMMask_roiMean.nii.gz \
	-expr "((${TE}/(${TE}/${T2static}-log(a)))-${T2static})/1000" \
	-prefix ${t2dir}/${sid}_POSSUM4D_bb264_roiAvg_bandpass.nii.gz

    #final input for full frequency, no ROI averaging
    3dcalc -a ${t2dir}/brnswktm_${t2base}_6_100voxelmean_scale1_1mm_264GMMask+tlrc \
	-expr "((${TE}/(${TE}/${T2static}-log(a)))-${T2static})/1000" \
	-prefix ${t2dir}/${sid}_POSSUM4D_bb264_fullFreq.nii.gz

    #final input for bandpass filtered data, no ROI averaging
    3dcalc -a ${t2dir}/brnswktm_${t2base}_6_100voxelmean_scale1_1mm_264GMMask+tlrc \
	-expr "((${TE}/(${TE}/${T2static}-log(a)))-${T2static})/1000" \
	-prefix ${t2dir}/${sid}_POSSUM4D_bb264_bandpass.nii.gz

fi
exit 0

#leftovers from testing
3dROIstats -mask ${sid}_bb264_gmMask_fs+tlrc -nomeanout -nzvoxels -1DRformat bb264+tlrc > numgmVoxelsIn264ROIs_FS.1D

3dROIstats -mask ${sid}_bb264_gmMask_fast+tlrc -nomeanout -nzvoxels -1DRformat bb264+tlrc > numgmVoxelsIn264ROIs_FAST.1D

#compute correlations among 264 ROIs (just for checking/testing)
#inside mprage dir
3drefit -view orig bb264+tlrc
3drefit -view orig ${sid}_bb264_gmMask_fast+tlrc
3dcopy ${t2dir}/rnswktm_${t2base}_6_100voxelmean_noglobal.nii.gz rr_noglob
3dcopy ${t2dir}/rnswktm_${t2base}_6_100voxelmean.nii.gz rr
3drefit -view orig rr_noglob+tlrc
3drefit -view orig rr+tlrc

@ROI_Corr_Mat -ts rr_noglob+orig \
    -roi bb264+orig \
    -prefix ${sid}_bb264_corrmat_noglob \
    -zval 

@ROI_Corr_Mat -ts rr+orig \
    -roi bb264+orig \
    -prefix ${sid}_bb264_corrmat \
    -zval 

@ROI_Corr_Mat -ts rr_noglob+orig \
    -roi ${sid}_bb264_gmMask_fast+orig \
    -prefix ${sid}_bb264_corrmat_noglob_fast \
    -zval 

@ROI_Corr_Mat -ts rr+orig \
    -roi ${sid}_bb264_gmMask_fast+orig \
    -prefix ${sid}_bb264_corrmat_fast \
    -zval 

rm rr*
3drefit -view tlrc bb264+orig
3drefit -view tlrc ${sid}_bb264_gmMask_fast+orig





###OLD CODE FOR HANDLING T1.
#It didn't work to preprocess mprage from DICOMs because I was unable to match the T1.mgz file or aseg.mgz file from freesurfer
#using a grid expansion and reorientation alone.

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

    #trim aseg to coordinates of original mprage (to make comparable for warp)
    #N.B. This step isn't working. Yields weird and large offsets
    #The aseg must have been manipulated (e.g., deobliqued) in FS
    #Change approach to use T1.mgz as structural starting point (above)
    #3dresample -inset ${sid}_aseg.nii.gz -prefix ${sid}_aseg_trimmed.nii.gz -master mprage.nii.gz

    #TR=$TR /Users/lncd/src/Possum2sTR_ROIavg/ROIavgValues.bash -f ${t2dir}/rnswktm_${t2base}_6_100voxelmean_scale1_1mm_264GMMask+tlrc \
    #                                -roimask ${sid}_bb264_gmMask_fast+tlrc \
    #                                -o bb264means_functaion_6_100voxelmean_scale1_1mm_GMMask.nii.gz
