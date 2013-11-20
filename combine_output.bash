#!/usr/bin/env sh
#set -x
set -e

SimOutBase=$SCRATCH/possum_rsfcmri
CompleteBase=$SCRATCH/possum_complete
ArchiveBase=$SCRATCH/possum_archive

while [ -n "$1" ]; do
    case $1 in 
	-sim_cfg)  SimRun="$2";     shift 2;; # simulation configuration
	-njobs)    njobs=$2;        shift 2;; # number of jobs expected
	-pulse)    pulse="$2";      shift 2;; # pulse file required to reconstruct images
	*) echo -e "[Unrecognized option: '$1']";
	    exit 1;;
    esac
done

[ -z "$njobs" ] && echo "Must specify number of jobs expected: -njobs <n>." && exit 1
[ -z "$SimRun" ] && echo "Must specify simulation configuration: -sim_cfg <string>." && exit 1
[ -z "$pulse" ] && echo "Must specify pulse file basename: -pulse <string>" && exit 1

#allow -sim_cfg and -pulse to include directory (which will be stripped).
#makes it a bit easier to use bash completion to call the script.
SimRun=$( basename $SimRun )
pulse=$( basename $pulse )

inputDir=$HOME/Possum_Motion/defaults

#use return code from ls to determine if output directory exists.
#good method for finding whether dir exists 
#SimOutDir=$( find $SimOutBase -type d -maxdepth 1 -name '${SimRun}*' -print -quit )

#ls -d "${SimOutBase}/${SimRun}"*
#echo $?
SimOutDir=$(
   ls -d "${SimOutBase}/${SimRun}_"[0-9][0-9][A-Z]* 2>/dev/null |
   perl -lne "print if m:/${SimRun}_\d{2}(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec):"
)
if [ -z "$SimOutDir" ]; then
    echo "Unable to locate output directory for simulation config: $SimRun"
    exit 1
fi

echo "outdir: $SimOutDir"

noutputs=$( find $SimOutDir/output -iname "possum_*" -type f | wc -l )

if [ $noutputs -ne $njobs ] && [ $noutputs -gt 0 ]; then
    echo "Number of possum outputs: $noutputs. Num expected: $njobs."
    exit 1
fi

echo "noutputs: $noutputs"

[ ! -d "${SimOutDir}/combined" ] && mkdir "${SimOutDir}/combined"

if [ ! -f "${SimOutDir}/combined/${SimRun}_possum_simt2_abs.nii.gz" ] && [ ! -f "${SimOutDir}/combined/${SimRun}_possum_simt2_abs.nii" ]; then
    echo -e "\nCombined possum output does not exist. Now combining images.\n"

    possum_sum -i ${SimOutDir}/output/possum_ -o ${SimOutDir}/combined/possum_combined -n ${njobs} -v 2>&1          |
    tee $SimOutDir/combined/possum_sum-$(date +%F).log

    signal2image -i ${SimOutDir}/combined/possum_combined -a --homo -p $inputDir/$pulse -o "${SimOutDir}/combined/${SimRun}_possum_simt2" |
    tee $SimOutDir/combined/signal2image-$(date +%F).log    
fi

if [ -r "${SimOutDir}/combined/${SimRun}_possum_simt2_abs.nii" ] || [ -r "${SimOutDir}/combined/${SimRun}_possum_simt2_abs.nii.gz" ]; then
    echo -e "\nPossum combination of individual inputs appears to have succeeded.\n\n----------"
    echo -e "Combined POSSUM file listing:\n----------\n"
    ls -lh "$SimOutDir/combined" && echo ""

    unset archiveCombined
    until [[ "$archiveCombined" = [NnYy] ]]; do
        read -sn1 -p "Create archive of combined files? (y/n)" archiveCombined
    done
    
    case ${archiveCombined} in
	y|Y) echo -e "\n*** Archiving combined"; (cd ${SimOutDir}/combined && tar cvzf "${ArchiveBase}/${SimRun}_complete.tar.gz" ./*) ;;
	n|N) echo -e "\nExiting script"; exit 1 ;;
    esac

    echo -e "\n----------\nPOSSUM output file listing (separate jobs)\n"
    echo -e "  Num outputs: $( ls ${SimOutDir}/output/possum_[0-9]* 2> /dev/null | wc -l )"
    echo -e "  File listing:\n----------\n"
    ( cd ${SimOutDir}/output && ls possum_[0-9]* 2> /dev/null )

    unset deletePossumSep
    until [[ "$deletePossumSep" = [NnYy] ]]; do
        read -sn1 -p "Delete separate possum matrices (job outputs)? (y/n)" deletePossumSep
    done
    
    case ${deletePossumSep} in
	y|Y) echo -e "\n*** Deleting possum matrices"; ( rm ${SimOutDir}/output/possum_[0-9]* > /dev/null 2>&1 ) ;;
	n|N) echo -e "\nSkipping deletion of POSSUM matrices" ;;
    esac

    echo -e "\n----------\nTransfer simulation to complete runs\n"
    echo "  Directory: ${SimOutDir}"
    echo "  Move to: ${CompleteBase}/$( basename ${SimOutDir} )"
    unset moveComplete
    until [[ "$moveComplete" = [NnYy] ]]; do
        read -sn1 -p "Move simulation run to complete? (y/n)" moveComplete
    done
    
    case ${moveComplete} in
	y|Y) echo -e "\n*** Moving simulation to complete"; mv ${SimOutDir} ${CompleteBase} ;;
	n|N) echo -e "\nExiting script"; exit 1 ;;
    esac
    
fi