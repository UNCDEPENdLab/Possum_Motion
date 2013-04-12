#!/usr/bin/env bash
set -ex

#if no parameters are passed in, then print help and exit.
if [ $# -eq 0 ]; then
    echo "No command line parameters passed. Need -4d and -t1 volumes. Optionally, -smoothing_kernel <mm> -chop_vols <nchop>"
    exit 0
fi

funcFile=
TR=
procprefix=
smoothing_kernel=6
chop_vols=8 #default is to discard 5 volumes for stabilization of magnetization, 3 volumes for static intensity baseline
bpLow=.009
bpHigh=.08

#process command line parameters
while [ _$1 != _ ] ; do
    if [[ $1 = -4d || $1 = -4D ]] ; then
	funcFile="${2}"
	funcNifti="${funcFile}" #retains file extension
	shift 2
    elif [[ $1 = -activ4d || $1 = -activ4D ]] ; then
	activ4D="${2}"
	shift 2
    elif [ $1 = -bp ] ; then
	bpLow="${2}"
	bpHigh="${3}"
	shift 3
    elif [ $1 = -smoothing_kernel ] ; then
        smoothing_kernel=${2}
        shift 2
    elif [ $1 = -chop_vols ] ; then
        chop_vols=${2}
        shift 2
    elif [ $1 = -t1 ] ; then
        templateT1=${2}
        shift 2
    else
	echo -e "----------------\n\n"
	echo "Unrecognized command line parameter: ${1}"
	exit 1
    fi
done
sigma=$( echo "scale=5; $smoothing_kernel/2.355" | bc )

[ -z "${templateT1}" ] && echo "Template T1 image required: -t1." && exit 1
[ -z "${funcFile}" ] && echo "Simulated 4D NIFTI image required: -4d." && exit 1
[ -z "${activ4D}" ] && echo "4D Activation input required: -activ4D." && exit 1

if [ $( imtest ${funcFile} ) -eq 0 ]; then
    echo -e "Raw functional 4D file: $funcFile does not exist.\nPass in as -4d parameter. Exiting.\n"
    exit 1
else
    funcFile=$( remove_ext ${funcFile} )
fi

if [ $( imtest ${activ4D} ) -eq 0 ]; then
    echo -e "Activation 4D input file: $activ4D does not exist.\nPass in as -activ4D parameter. Exiting.\n"
    exit 1
else
    #convert activ4d to absolute path (if not already)
    activ4D="$( cd -- "$(dirname ${activ4D})" && pwd)/$(basename ${activ4D})"
    activ4D=$( remove_ext ${activ4D} )
fi

if [ $( imtest ${templateT1} ) -eq 0 ]; then
    echo -e "Template t1 input file: $templateT1 does not exist.\nPass in as -t1 parameter. Exiting.\n"
    exit 1
else
    #convert t1 to absolute path (if not already)
    templateT1="$( cd -- "$(dirname ${templateT1})" && pwd)/$(basename ${templateT1})"
fi

scriptDir=$(echo $(cd $(dirname $0); pwd) )
funcDir="$( cd -- "$(dirname ${funcFile})" && pwd)" #convert to abs path
#should probably require this as a parameter
templateGMMask="$scriptDir/buildTemplate/10895/mprage/10895_bb264_gmMask_fast_bin+tlrc"

mniTemplate_3mm="$scriptDir/buildTemplate/mni_refs/mni_icbm152_t1_tal_nlin_asym_09c_brain_3mm"
mniTemplate_1mm="$scriptDir/buildTemplate/mni_refs/mni_icbm152_t1_tal_nlin_asym_09c_brain"
mniMask_3mm="$scriptDir/buildTemplate/mni_refs/mni_icbm152_t1_tal_nlin_asym_09c_mask_3mm"
mniMask_1mm="$scriptDir/buildTemplate/mni_refs/mni_icbm152_t1_tal_nlin_asym_09c_mask"
roiMask="$scriptDir/buildTemplate/10895/mprage/10895_bb264_gmMask_fast_RPI+tlrc"

#obtain TR from func file (original funcFile from POSSUM is trustworthy), round to 3 dec
detectTR=$( fslhd ${funcFile} | grep "^pixdim4" | perl -pe 's/pixdim4\s+(\d+)/\1/' | xargs printf "%1.3f" )

#remove initial volumes corresponding to discarded volumes from scanner
#spins have not reached steady state yet and intensities are quite sharp

numVols=$( fslhd ${funcNifti}  | grep '^dim4' | perl -pe 's/dim4\s+(\d+)/\1/' )
[ $( imtest ${funcFile}_trunc${chop_vols} ) -eq 0 ] && \
    fslroi ${funcFile} ${funcFile}_trunc${chop_vols} ${chop_vols} $(( ${numVols} - ${chop_vols} )) #fslroi uses 0-based indexing with params: first vol, length

[ $( imtest ${funcDir}/firstVol ) -eq 0 ] && \
    fslroi ${funcFile} ${funcDir}/firstVol 0 1 #used for BBR co-registration (has best contrast)

if [ $( imtest ${funcDir}/staticIntensity ) -eq 0 ]; then
    fslroi ${funcFile} ${funcDir}/staticIntensity 5 3 #used for baseline intensity % change computation
    fslmaths ${funcDir}/staticIntensity -Tmean ${funcDir}/staticIntensity #take temporal mean over the three static volumes
fi

# ensure that chopped files are used moving forward
# change to the directory of the functional for further processing
cd $funcDir
funcFile=$(basename $funcFile) #strip directory

funcFile=${funcFile}_trunc${chop_vols}
funcNifti=${funcFile}.nii.gz

#did it get the right 
[ ! -r $funcNifti ] && ! gzip $funcFile.nii && echo "failed to truncate $funcFile" && exit 1

#obtain the WM image from the template brain for use with BBR
[ $( imtest wm_brain ) -eq 0 ] && fslroi ${templateT1} wm_brain 1 1 #pull just the WM volume from the input brain

#1. motion correction
if [ ! -f m_${funcNifti} ]; then
   #align to middle volume (was using mean, but seems less directly interpretable in this context)
   #mcflirt -in functional -o m_functional -meanvol -stages 4 -sinc_final -rmsabs -rmsrel

   #to be consistent with func-to-struc warp below, use the firstVol as the target for motion co-registration
   mcflirt -in ${funcFile} -o m_${funcFile} -stages 4 -spline_final -rmsabs -rmsrel -plots -reffile firstVol #if omit refvol, defaults to middle

   #quick reduce to 3-stage for testing (go back to sinc_final once script works)
   # input: t_* output: mt_*
   #input=${procprefix:1}_${funcFile}
   #[ -z "${procprefix:1}" ] && input=$funcFile # input is raw, no prefix exists
   #mcflirt -in $input -o ${procprefix}_${funcFile} -stages 3 -rmsabs -rmsrel -plots #if omit refvol, defaults to middle
fi

#2. slice timing correction
if [ ! -f tm_${funcNifti} ]; then
    slicetimer -i m_${funcFile} -o tm_${funcFile} -r ${detectTR}
    slicetimer -i ${funcFile} -o t_${funcFile} -r ${detectTR} #also get slice timing alone
fi

#sticking with traditional preprocessing above for main pipeline. but test 4d correction here
#1. & 2.  slice time and motion correction
if [ ! -f j_${funcNifti} ]; then
    # ascending = z+ in possum pulse creation
    sliceMotion4D --inputs ${funcNifti} --tr ${detectTR} --slice_order ascending --prefix j_
fi

#3. skull strip mean functional
if [ ! -f ktm_${funcNifti} ]; then
    fslmaths tm_${funcFile} -Tmean tm_mean_${funcFile} #generate mean functional
    bet tm_mean_${funcFile} ktm_mean_${funcFile} -R -f 0.3 -m #skull strip mean functional
    fslmaths tm_${funcFile} -mas ktm_mean_${funcFile}_mask ktm_${funcFile} #apply skull strip mask to 4d file
fi

#consistent with FEAT and preprocessFunctional, mask out low intensity voxels approximating skull strip
#needed for susan threshold
p_2=$( fslstats ktm_${funcFile} -p 2 )
p_98=$( fslstats ktm_${funcFile} -p 98 )
thresh=$( echo "scale=5; $p_2 + ($p_98 - $p_2)/10" | bc ) #low intensity threshold

#threshold low intensity voxels within the skull-stripped mask
fslmaths ktm_${funcFile} -thr $thresh -Tmin -bin ktm_${funcFile}_98_2_mask -odt char

#compute the median intensity (prior to co-registration) of voxels within the BET mask
median_intensity=$( fslstats tm_${funcFile} -k ktm_mean_${funcFile}_mask -p 50 )

#dilate mask 1x
fslmaths ktm_${funcFile}_98_2_mask -dilF ktm_${funcFile}_98_2_mask_dil1x

#apply low intensity mask -- should be a loose skull strip (unlikely to lose brain voxels)
fslmaths tm_${funcFile} -mas ktm_${funcFile}_98_2_mask_dil1x ktm_${funcFile}_masked

#from FEAT
susan_thresh=$( echo "scale=5; ($median_intensity - $p_2) * 0.75" | bc )

#4. co-register the POSSUM output with the POSSUM anatomical (T1) input.
#N.B.: The POSSUM T1 input is already in MNI space and of the desired orientation and voxel size.
#Thus, the task here is co-registration, NOT warping per se.

#Use BBR-based registration (previously used 3 DOF translation)
#standard 6 parameter EPI-to-T1 registration to get initial estimate of transform                                                                                            
[ ! -r func_to_mprage_init.mat ] && flirt -in firstVol -ref wm_brain -out func_to_mprage -omat func_to_mprage_init.mat -dof 6

#register first volumes to WM T1 segmentation
if [ ! -r func_to_mprage.mat ]; then
    #now do the BBR-based registration
    flirt -in firstVol -ref wm_brain -out func_to_mprage -omat func_to_mprage.mat \
	-wmseg wm_brain -cost bbr -init func_to_mprage_init.mat -dof 6 \
	-schedule ${FSLDIR}/etc/flirtsch/bbr.sch \
	-interp sinc -sincwidth 7 -sincwindow hanning
fi

#5. warp to MNI
#N.B. This is slow and RAM intensive because of 1mm size of reference
#will warp several preceding datasets into MNI to obtain 264 ROI time courses for each step

#first warp subject mask to MNI to constrain warps
#warp subject mask to 1mm MNI-POSSUM brain using NN
flirt -in ktm_${funcFile}_98_2_mask_dil1x \
    -ref wm_brain \
    -out wktm_${funcFile}_98_2_mask_dil1x \
    -applyxfm -init func_to_mprage.mat \
    -interp nearestneighbour

#ensure that subject mask does not extend beyond bounds of anatomical mask, but may be smaller
#subtract mni anatomical mask from subject's mask, then threshold at zero (neg values represent areas where anat mask > subj mask)
[ $( imtest wktm_outofbounds_mask ) -eq 0 ] && fslmaths wktm_${funcFile}_98_2_mask_dil1x -sub ${mniMask_1mm} -thr 0 wktm_outofbounds_mask -odt char

[ $( imtest wktm_${funcFile}_mask_anatTrim ) -eq 0 ] && fslmaths wktm_${funcFile}_98_2_mask_dil1x -sub wktm_outofbounds_mask wktm_${funcFile}_mask_anatTrim -odt char

#run these in parallel

# 1) raw 4d data
if [ $( imtest w_${funcFile} ) -eq 0 ]; then
    (    
        #warp raw POSSUM output to subject template (MNI)
	flirt -in ${funcFile} \
	    -ref wm_brain \
	    -out ${funcDir}/w_${funcFile} \
	    -applyxfm -init func_to_mprage.mat \
	    -interp sinc -sincwidth 7 -sincwindow hanning
            #-interp spline	

        #constrain warped functional to subject + MNI mask
	fslmaths ${funcDir}/w_${funcFile} -mas wktm_${funcFile}_mask_anatTrim ${funcDir}/w_${funcFile}
    ) &
fi

# 2) motion correction only
if [ $( imtest wm_${funcFile} ) -eq 0 ]; then
    ( 
        #warp raw POSSUM output to subject template (MNI)
	flirt -in m_${funcFile} \
	    -ref wm_brain \
	    -out ${funcDir}/wm_${funcFile} \
	    -applyxfm -init func_to_mprage.mat \
	    -interp sinc -sincwidth 7 -sincwindow hanning
            #-interp spline	

        #constrain warped functional to subject + MNI mask
	fslmaths ${funcDir}/wm_${funcFile} -mas wktm_${funcFile}_mask_anatTrim ${funcDir}/wm_${funcFile}
    ) &
fi

# 3) slice time correction only
if [ $( imtest wt_${funcFile} ) -eq 0 ]; then
    (    
        #warp raw POSSUM output to subject template (MNI)
	flirt -in t_${funcFile} \
	    -ref wm_brain \
	    -out ${funcDir}/wt_${funcFile} \
	    -applyxfm -init func_to_mprage.mat \
	    -interp sinc -sincwidth 7 -sincwindow hanning
            #-interp spline	

        #constrain warped functional to subject + MNI mask
	fslmaths ${funcDir}/wt_${funcFile} -mas wktm_${funcFile}_mask_anatTrim ${funcDir}/wt_${funcFile}
    ) &
fi

# 4) slice timing and motion correction
if [ $( imtest wtm_${funcFile} ) -eq 0 ]; then
    (
        #warp raw POSSUM output to subject template (MNI)
	flirt -in tm_${funcFile} \
	    -ref wm_brain \
	    -out ${funcDir}/wtm_${funcFile} \
	    -applyxfm -init func_to_mprage.mat \
	    -interp sinc -sincwidth 7 -sincwindow hanning
            #-interp spline	

        #constrain warped functional to subject + MNI mask
	fslmaths ${funcDir}/wtm_${funcFile} -mas wktm_${funcFile}_mask_anatTrim ${funcDir}/wtm_${funcFile}
    ) &
fi

# 5) skull strip, slice timing, and motion correction
if [ $( imtest wktm_${funcFile} ) -eq 0 ]; then
    (    
        #warp raw POSSUM output to subject template (MNI)
	flirt -in ktm_${funcFile}_masked \
	    -ref wm_brain \
	    -out ${funcDir}/wktm_${funcFile} \
	    -applyxfm -init func_to_mprage.mat \
	    -interp sinc -sincwidth 7 -sincwindow hanning
            #-interp spline	

        #constrain warped functional to subject + MNI mask
	fslmaths ${funcDir}/wktm_${funcFile} -mas wktm_${funcFile}_mask_anatTrim ${funcDir}/wktm_${funcFile}
    ) &
fi

# 6) joint slice timing and motion
if [ $( imtest wj_${funcFile} ) -eq 0 ]; then
    (    
        #warp raw POSSUM output to subject template (MNI)
	flirt -in j_${funcFile} \
	    -ref wm_brain \
	    -out ${funcDir}/wj_${funcFile} \
	    -applyxfm -init func_to_mprage.mat \
	    -interp sinc -sincwidth 7 -sincwindow hanning
            #-interp spline	

        #constrain warped functional to subject + MNI mask
	fslmaths ${funcDir}/j_${funcFile} -mas wktm_${funcFile}_mask_anatTrim ${funcDir}/j_${funcFile}
    ) &
fi

#also warp static tissue to MNI to get baseline
if [ $( imtest ${funcDir}/staticIntensity_t1warp ) -eq 0 ]; then
    (
	flirt -in ${funcDir}/staticIntensity \
	    -ref wm_brain \
	    -out ${funcDir}/staticIntensity_t1warp \
	    -applyxfm -init func_to_mprage.mat \
	    -interp sinc -sincwidth 7 -sincwindow hanning

        #constrain warped functional to subject + MNI mask
	fslmaths ${funcDir}/staticIntensity_t1warp -mas wktm_${funcFile}_mask_anatTrim ${funcDir}/staticIntensity_t1warp
    ) &
fi

wait

#use static tissue intensity in the initial volumes to serve as baseline for scaling PSC
3dROIstats -mask ${roiMask} -1DRformat ${funcDir}/staticIntensity_t1warp.nii.gz > ${funcDir}/roi264_meanTCs_baseline.1D

#compute mean time courses for activation input in the 264 ROIs
3dROIstats -mask ${roiMask} -1DRformat ${activ4D}.nii.gz > ${funcDir}/roi264_meanTCs_inputActivation.1D

function save264TCs() {
    input="$1"
    preprocSteps="$2" #used for file suffix to denote steps performed
    output="${funcDir}/roi264_meanTCs_${preprocSteps}.1D"

    3dROIstats -mask ${roiMask} -1DRformat "$input" > $output
}

#save time courses for initial slice timing, motion, and raw
save264TCs w_${funcFile}.nii.gz w
save264TCs wt_${funcFile}.nii.gz wt
save264TCs wn_${funcFile}.nii.gz wm
save264TCs wtm_${funcFile}.nii.gz wtm
save264TCs wktm_${funcFile}.nii.gz wktm
save264TCs wj_${funcFile}.nii.gz wj

#N.B. The rest of preprocessing proceeds at 1mm resolution. This is costly in terms of time and RAM
#but need to get snapshots of 264 ROI TCs along the way, which should be done at 1mm.

############
# 5. smooth
if [ ! -f swktm_${funcFile}_${smoothing_kernel}.nii.gz ]; then
    #prior to smoothing, create an extents mask to ensure that all time series are sampled at all timepoints
    fslmaths wktm_${funcFile} -Tmin -bin extents_mask -odt char

    fslmaths wktm_${funcFile} -Tmean wktm_mean_${funcFile}
    susan wktm_${funcFile} ${susan_thresh} ${sigma} 3 1 1 wktm_mean_${funcFile} ${susan_thresh} swktm_${funcFile}_${smoothing_kernel}

    #now apply the extents mask to eliminate excessive blurring due to smooth and only retain voxels fully sampled in unsmoothed space
    fslmaths swktm_${funcFile}_${smoothing_kernel} -mul extents_mask swktm_${funcFile}_${smoothing_kernel} -odt float
fi

save264TCs swktm_${funcFile}_${smoothing_kernel}.nii.gz swktm

##########
# 6. scale to PSC
# use static tissue intensity to scale intensities to percent signal change

3dcalc -a swktm_${funcFile}_${smoothing_kernel}.nii.gz -b staticIntensity_t1warp.nii.gz \
    -expr '((a/b) - 1)*100' -prefix pswktm_${funcFile}_${smoothing_kernel}.nii.gz

save264TCs pswktm_${funcFile}_${smoothing_kernel}.nii.gz pswktm

#need to think more about how to preserve PSC scaling after bandpass filtering... since there is a detrending process, the
#means go to zero (remove the DC component) and scaling may change.

##########
# 7. bandpass
#use 3dBandpass here for consistency (no nuisance regression, of course)
#in particular, this is used to quadratic detrend all voxel time series, which makes the scaling to 1.0 sensible.
# "(2) Removal of a constant+linear+quadratic trend"
#otherwise, the -ing 100 makes all brain voxels high and all air voxels low. Would need to ing within mask otherwise.

if [ ! -f bpswktm_${funcFile}_${smoothing_kernel}.nii.gz ]; then
    3dBandpass -overwrite -input pswktm_${funcFile}_${smoothing_kernel}.nii.gz -mask extents_mask.nii.gz \
	-prefix bpswktm_${funcFile}_${smoothing_kernel}.nii.gz ${bpLow} ${bpHigh}
fi


# DSET_NVALS(inset) < 9 == FATAL ERROR: Input dataset is too short!
# but 3dbandpass needs a min num of subvolumes  and when we remove the first 4 "junk" volumes, we are below this.
# so we'll use 3dDetrend: make the sum-of-squares equal to 1
# no mask for where the brain is with 3dDetrend?
#3dDetrend  -expr 't^2+t'\
#           -prefix ${procprefix}_${funcFile}_${smoothing_kernel}.nii.gz \
#           ${procprefix:1}_${funcFile}_${smoothing_kernel}.nii.gz
#           #-mask extents_mask.nii.gz \

#intensity normalization to mean 1.0. This makes it comparable to the original activation input (before T2* scaling)
#logic: add some constant to all voxels, then determine the grand mean intensity scaling factor to achieve M = 100
#this will make non-brain voxels 100, and voxels within the brain ~100
#necessary to scale away from 0 to allow for division against baseline to yield PSC
#Otherwise, leads to division by zero problems. (should not be problematic here since we did not detrend voxel time series)
#fslmaths ${procprefix}_${funcFile}_${smoothing_kernel} -add 100 -ing 100 ${procprefix}_${funcFile}_${smoothing_kernel}_scaleM100 -odt float

#####
# 7. normalize
#procprefix="n$procprefix" #nbswkmt_
#dividing the M=100 file by 100 yields a proportion of mean scaling (PSC)
#fslmaths ${procprefix:1}_${funcFile}_${smoothing_kernel}_scaleM100 -div 100 ${procprefix}_${funcFile}_${smoothing_kernel}_scale1 -odt float

#okay, should have achieved the functional input with all proper preprocessing and scaling

#need to upsample the final file to 1mm voxels for comparison with original input
#upsample the preproc data (scale 1) into 1mm voxels to match GM mask
#flirt -in ${procprefix}_${funcFile}_${smoothing_kernel}_scale1 \
#    -ref ${mniTemplate_1mm} \
#    -applyxfm -init ${FSLDIR}/etc/flirtsch/ident.mat \
#    -out ${procprefix}_${funcFile}_${smoothing_kernel}_scale1_1mm -paddingsize 0.0 -interp nearestneighbour

#now should apply the 244 GM mask to these data for comparison
#3dcalc -overwrite -a ${procprefix}_${funcFile}_${smoothing_kernel}_scale1_1mm.* -b ${templateGMMask} -expr 'a*b' \
#    -prefix ${procprefix}_${funcFile}_${smoothing_kernel}_scale1_1mm_244GMMask.nii.gz


####
#END


#OLD CO-REGISTRATION CODE
#procprefix="w$procprefix" #wkmt_
#N.B.: The POSSUM T1 input is already in MNI space and of the desired orientation and voxel size.
#Thus, the task here is co-registration, NOT warping per se.

#Sensible: force flirt to 3 df to allow for translation only since there should be a 1:1 match with the input.
#i.e., the relative position and size of the POSSUM output should precisely match input.
#Is there a possibility that more df will be needed to co-register once we have motion to contend with?
#The mean functional may (prob. not) include some imprecision due to residual motion effects. Cross that bridge when we come to it.
#Use the 1mm template T1 to maximize similarity to input. Using 3mm downsampled T1s tended to shift translations ~0.5mm.
#flirt -in ${procprefix:1}_mean_${funcFile} -ref ${templateT1} -out func_to_mprage -omat func_to_mprage.mat \
#    -dof 6 -schedule ${FSLDIR}/etc/flirtsch/sch3Dtrans_3dof \
#    -interp sinc -sincwidth 7 -sincwindow hanning

#warp subject mask to 3mm MNI-POSSUM brain using NN
#shouldn't matter whether MNI template or 10653 since ref is just used for image geometry
#applywarp \
#    --ref=${mniTemplate_3mm} \
#    --in=${procprefix:1}_mean_${funcFile}_mask \
#    --out=${procprefix}_${funcFile}_mask \
#    --premat=func_to_mprage.mat \
#    --interp=nn


####
#CONSIDER THE POSSIBILITY THAT WARPING TO MNI 3mm, then upsampling to MNI 1mm to match template may induce a lot of
#interpolation problems. What if a bunch of static voxels get mixed into the 264 ROIs in the MNI 3mm warp?
#Maybe warp the raw POSSUM directly to the 1mm template.
#And also consider avoiding nn for upsampling?

#this is now handled above
#co-register POSSUM-simulated functional to POSSUM input structural at 1mm.
#stick with spline interpolation for now. Sinc has tendency to blur far outside the mask (as I knew),
#but what is striking here is that any limitations of the mask are quite magnified by the sinc interpolation, but not spline
#applywarp --ref=${mniTemplate_1mm} \
#    --in=ktm_${funcFile}_masked --out=wktm_${funcFile} --premat=func_to_mprage.mat \
#    --interp=spline --mask=${procprefix}_${funcFile}_mask_anatTrim
