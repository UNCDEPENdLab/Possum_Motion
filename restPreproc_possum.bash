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
chop_vols=3 #3dbp says 1 transient issue with 4

#process command line parameters
while [ _$1 != _ ] ; do
    if [[ $1 = -4d || $1 = -4D ]] ; then
	funcFile="${2}"
	funcNifti="${funcFile}" #retains file extension
	shift 2
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

if [ $( imtest ${funcFile} ) -eq 0 ]; then
    echo -e "Raw functional 4D file: $funcFile does not exist.\nPass in as -4d parameter. Exiting.\n"
    exit 1
else
    funcFile=$( remove_ext ${funcFile} )
fi

scriptDir=$(echo $(cd $(dirname $0); pwd) )
funcDir=$(dirname $funcFile)
#should probably require this as a parameter
templateGMMask="$scriptDir/buildTemplate/10895/mprage/10895_bb264_gmMask_fast_bin+tlrc"

mniTemplate_3mm="$scriptDir/buildTemplate/mni_refs/mni_icbm152_t1_tal_nlin_asym_09c_brain_3mm"
mniTemplate_1mm="$scriptDir/buildTemplate/mni_refs/mni_icbm152_t1_tal_nlin_asym_09c_brain"
mniMask_3mm="$scriptDir/buildTemplate/mni_refs/mni_icbm152_t1_tal_nlin_asym_09c_mask_3mm"

#obtain TR from func file (original funcFile from POSSUM is trustworthy), round to 3 dec
detectTR=$( fslhd ${funcFile} | grep "^pixdim4" | perl -pe 's/pixdim4\s+(\d+)/\1/' | xargs printf "%1.3f" )

#remove initial volumes corresponding to discarded volumes from scanner
#spins have not reached steady state yet and intensities are quite sharp

numVols=$( fslhd ${funcNifti}  | grep '^dim4' | perl -pe 's/dim4\s+(\d+)/\1/' )
fslroi ${funcFile} ${funcFile}_trunc${chop_vols} ${chop_vols} $(( ${numVols} - ${chop_vols} )) #fslroi uses 0-based indexing with params: first vol, length
fslroi ${funcFile} ${funcDir}/firstVol 0 1 #used for BBR co-registration
fslroi ${funcFile} ${funcDir}/thirdVol 2 1 #used for baseline intensity % change computation

#ensure that chopped files are used moving forward
# go where the funcfile is
cd $(dirname $funcFile)
funcFile=$(basename $funcFile)

funcFile=${funcFile}_trunc${chop_vols}
funcNifti=${funcFile}.nii.gz

#did it get the right 
[ ! -r $funcNifti ] && ! gzip $funcFile.nii && echo "failed to truncate $funcFile" && exit 1

#obtain the WM image from the template brain for use with BBR
[ $( imtest wm_brain ) -eq 0 ] && fslroi ${templateT1} wm_brain 1 1 #pull just the WM volume from the input brain

#1. slice timing correction
#placing first see here: http://mindhive.mit.edu/node/109
procprefix="t$procprefix"
if [ ! -f ${procprefix}_${funcNifti} ]; then
    slicetimer -i ${funcFile} -o ${procprefix}_${funcFile} -r ${detectTR}
fi

#2. motion correction
#procprefix="m$procprefix"
#if [ ! -f ${procprefix}_${funcNifti} ]; then
#    #align to middle volume (was using mean, but seems less directly interpretable in this context)
#    #mcflirt -in functional -o m_functional -meanvol -stages 4 -sinc_final -rmsabs -rmsrel
#    #mcflirt -in ${funcFile} -o m_${funcFile} -stages 4 -sinc_final -rmsabs -rmsrel -plots #if omit refvol, defaults to middle
#
#    #quick reduce to 3-stage for testing (go back to sinc_final once script works)
#    # input: t_* output: mt_*
#    input=${procprefix:1}_${funcFile}
#    [ -z "${procprefix:1}" ] && input=$funcFile # input is raw, no prefix exists
#    mcflirt -in $input -o ${procprefix}_${funcFile} -stages 3 -rmsabs -rmsrel -plots #if omit refvol, defaults to middle
#fi

#1. & 2.  slice time and motion correction 
#procprefix="mt$procprefix"
#if [ ! -f ${procprefix}_${funcNifti} ]; then
#     # ascending = z+ in possum pulse creation
#     sliceMotion4D --inputs ${funcNifti} --tr ${detectTR} --slice_order ascending
#     #defaults to -prefix mt   output saved as    mt_simBrain_trunc4.nii.gz
#fi

#3. skull strip mean functional
procprefix="k$procprefix" #kmt_
if [ ! -f ${procprefix}_${funcNifti} ]; then
    fslmaths ${procprefix:1}_${funcFile} -Tmean ${procprefix:1}_mean_${funcFile} #generate mean functional
    bet ${procprefix:1}_mean_${funcFile} ${procprefix}_mean_${funcFile} -R -f 0.3 -m #skull strip mean functional
    fslmaths ${procprefix:1}_${funcFile} -mas ${procprefix}_mean_${funcFile}_mask ${procprefix}_${funcFile} #apply skull strip mask to 4d file
fi

#compute the median intensity (prior to co-registration) of voxels within the BET mask
#(couldn't I just use kmt_${funcFile} since that has the mask applied?)
median_intensity=$( fslstats "${procprefix:1}_${funcFile}" -k "${procprefix}_mean_${funcFile}_mask" -p 50 )

#needed for susan threshold
p_2=$( fslstats "${procprefix}_${funcFile}" -p 2 )

#from FEAT
susan_thresh=$( echo "scale=5; ($median_intensity - $p_2) * 0.75" | bc )

#4. co-register the POSSUM output with the POSSUM anatomical (T1) input.
procprefix="w$procprefix" #wkmt_
#N.B.: The POSSUM T1 input is already in MNI space and of the desired orientation and voxel size.
#Thus, the task here is co-registration, NOT warping per se.

#Use BBR-based registration (previously used 3 DOF translation)
#standard 6 parameter EPI-to-T1 registration to get initial estimate of transform                                                                                            
[ ! -r func_to_mprage_init.mat ] && flirt -in firstVol -ref wm_brain -out func_to_mprage -omat func_to_mprage_init.mat -dof 6

if [ ! -r func_to_mprage.mat ]; then
    #now do the BBR-based registration
    flirt -in firstVol -ref wm_brain -out func_to_mprage -omat func_to_mprage.mat \
	-wmseg wm_brain -cost bbr -init func_to_mprage_init.mat -dof 6 \
	-schedule ${FSLDIR}/etc/flirtsch/bbr.sch \
	-interp sinc -sincwidth 7 -sincwindow hanning
fi

if [ $( imtest w${funcFile} ) -eq 0 ]; then
    #warp raw POSSUM output to subject template (MNI)
    flirt -in ${funcFile} \
	-ref ${templateT1} \
	-out w${funcFile} \
	-applyxfm -init func_to_mprage.mat \
	-interp sinc
fi

3dROIstats -mask ~/Possum_Motion/buildTemplate/10895/mprage/10895_bb264_gmMask_fast_RPI+tlrc -1DRformat w${funcFile}.nii.gz > ${funcDir}w_meanTimeCourses.1D

exit 1

#warp subject mask to 3mm MNI-POSSUM brain using NN
#shouldn't matter whether MNI template or 10653 since ref is just used for image geometry
flirt -in ${procprefix:1}_mean_${funcFile}_mask \
    -ref ${mniTemplate_3mm} \
    -out ${procprefix}_${funcFile}_mask \
    -applyxfm -init func_to_mprage.mat \
    -interp nearestneighbour

#ensure that subject mask does not extend beyond bounds of anatomical mask, but may be smaller
#subtract mni anatomical mask from subject's mask, then threshold at zero (neg values represent areas where anat mask > subj mask)
fslmaths ${procprefix}_${funcFile}_mask -sub ${mniMask_3mm} -thr 0 ${procprefix}_outofbounds_mask -odt char

fslmaths ${procprefix}_${funcFile}_mask -sub ${procprefix}_outofbounds_mask ${procprefix}_${funcFile}_mask_anatTrim -odt char

####
#CONSIDER THE POSSIBILITY THAT WARPING TO MNI 3mm, then upsampling to MNI 1mm to match template may induce a lot of
#interpolation problems. What if a bunch of static voxels get mixed into the 264 ROIs in the MNI 3mm warp?
#Maybe warp the raw POSSUM directly to the 1mm template.
#And also consider avoiding nn for upsampling?


#co-register POSSUM-simulated functional to POSSUM input structural at 3mm. (1mm co-registration above mostly for affine mat.
#stick with spline interpolation for now. Sinc has tendency to blur far outside the mask (as I knew),
#but what is striking here is that any limitations of the mask are quite magnified by the sinc interpolation, but not spline
applywarp --ref=${mniTemplate_3mm} \
    --in=${procprefix:1}_${funcFile} --out=${procprefix}_${funcFile} --premat=func_to_mprage.mat \
    --interp=spline --mask=${procprefix}_${funcFile}_mask_anatTrim

#prior to smoothing, create and an extents mask to ensure that all time series are sampled at all timepoints
fslmaths ${procprefix}_${funcFile} -Tmin -bin extents_mask -odt char

############
# 5. smooth
procprefix="s$procprefix" #swkmt_
if [ ! -f ${procprefix}_${funcFile}_${smoothing_kernel}.nii.gz ]; then
    fslmaths ${procprefix:1}_${funcFile} -Tmean ${procprefix:1}_mean_${funcFile}
    susan ${procprefix:1}_${funcFile} ${susan_thresh} ${sigma} 3 1 1 ${procprefix:1}_mean_${funcFile} ${susan_thresh} ${procprefix}_${funcFile}_${smoothing_kernel}
fi

#now apply the extents mask to eliminate excessive blurring due to smooth and only retain voxels fully sampled in unsmoothed space
fslmaths ${procprefix}_${funcFile}_${smoothing_kernel} -mul extents_mask ${procprefix}_${funcFile}_${smoothing_kernel} -odt float

##########
# 6. bandpass
procprefix="b$procprefix" #bswkmt_
#use 3dBandpass here for consistency (no nuisance regression, of course)
#in particular, this is used to quadratic detrend all voxel time series, which makes the scaling to 1.0 sensible.
# "(2) Removal of a constant+linear+quadratic trend"
#otherwise, the -ing 100 makes all brain voxels high and all air voxels low. Would need to ing within mask otherwise.

3dBandpass -overwrite -input ${procprefix:1}_${funcFile}_${smoothing_kernel}.* -mask extents_mask.* \
    -prefix ${procprefix}_${funcFile}_${smoothing_kernel}.nii.gz 0 99999

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
fslmaths ${procprefix}_${funcFile}_${smoothing_kernel} -add 100 -ing 100 ${procprefix}_${funcFile}_${smoothing_kernel}_scaleM100 -odt float

#####
# 7. normalize
procprefix="n$procprefix" #nbswkmt_
#dividing the M=100 file by 100 yields a proportion of mean scaling (PSC)
fslmaths ${procprefix:1}_${funcFile}_${smoothing_kernel}_scaleM100 -div 100 ${procprefix}_${funcFile}_${smoothing_kernel}_scale1 -odt float

#okay, should have achieved the functional input with all proper preprocessing and scaling

#need to upsample the final file to 1mm voxels for comparison with original input
#upsample the preproc data (scale 1) into 1mm voxels to match GM mask
flirt -in ${procprefix}_${funcFile}_${smoothing_kernel}_scale1 \
    -ref ${mniTemplate_1mm} \
    -applyxfm -init ${FSLDIR}/etc/flirtsch/ident.mat \
    -out ${procprefix}_${funcFile}_${smoothing_kernel}_scale1_1mm -paddingsize 0.0 -interp nearestneighbour

#now should apply the 244 GM mask to these data for comparison
3dcalc -overwrite -a ${procprefix}_${funcFile}_${smoothing_kernel}_scale1_1mm.* -b ${templateGMMask} -expr 'a*b' \
    -prefix ${procprefix}_${funcFile}_${smoothing_kernel}_scale1_1mm_244GMMask.nii.gz



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
