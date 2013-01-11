function avgValWiROIs {
    t2rest=$1
    #t2noext=$( remove_ext ${t2rest} ) #using AFNI inputs, not FSL
    t2noext=$( echo $t2rest | perl -pe 's/(.*)(\+tlrc\.BRIK.gz|\+tlrc\.BRIK|\+tlrc\.HEAD|\+tlrc)/\1/' )

    ####ROI AVERAGE CODE
    #tweak preprocessed data to replace activation values with mean activation within each sphere (GM-masked)
    #developed by Will in ROIavgValues.bash and adapted here
    numImgs=$(3dinfo ${t2rest} | perl -lne 'print $1 if /time steps = (\d+)/')

    [ -d join ] && rm -r join
    mkdir join && cd join || exit 1

    set -x
    # use -nomeanout  and -nzmean  if want to mask out WM, add -mask bb244+tlrc to 3dUndump
    # or if roimask is bb244-WM, will only average desired -- should mask final outupt again though (so spheres are pacman-ish again)

    #obtain mean within gray matter voxels of each of the 264 ROIs. This yields a Time x ROI matrix (150 x 264) of means within ROIs.
    3dROIstats -numROI 264 -1Dformat -mask ${t1dir}/${sid}_bb264_gmMask_fast+tlrc \
	${t2rest} > ROIstats.1D || exit 1
    
    # transpose to get a 264 x 150 (ROI x Time) matrix
    1dtranspose ROIstats.1D > tROIstats.1D || exit 1

    # join the original coordinate file with the i-th column of roistats as the value of the coordinate, with srad of 5
    # use linenumber as key to join:  field 4 in coord file, field 1 on awk printed roistat out
    # (then remove the join key (now the first column) with cut)                                                                                                                            
    for i in `seq 1 $numImgs`; do
	outname=$(printf "%04d" $i)
        # add -mask bb244+tlrc to mask back out the means, use -nzmean -nomeanout in 3dROIstats                                                                                                
	awk "{print NR, \$$i}" tROIstats.1D  > $outname.txt
        #join -1 4 -2 1 $bbCoorFile  $outname.txt | cut -d' ' -f2- > $outname.merged # THIS SKIPS from 13 to 90! why?                                                                          
	join -1 4 -2 1 $roiCoord <(sed '/0$/d' $outname.txt)| cut -d' ' -f2- > $outname.merged
	[ $(cat $outname.merged|wc -l) -ne 264 ] && echo "$outname.merged was not created correctly" && exit
	3dUndump -overwrite -prefix $outname.nii -mask ${t1dir}/${sid}_bb264_gmMask_fast_bin+tlrc \
	    -master ${t2rest} \
	    -srad 5 -datum float -xyz $outname.merged
    done
    set +x

    3dTcat -prefix ${t2noext}_roiMean.nii.gz [0-9]*.nii.gz
    3drefit -TR $TR ${t2noext}_roiMean.nii.gz
    
    cd ${t2dir}
    rm -rf join
}
