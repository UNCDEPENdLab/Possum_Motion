#!/bin/bash
#messed up the possum output numbering in the first iteration: named outputs based on 1-based vector (1..32)
#this switches to 0..31, as expected by possum_sum
#note: qsub_possumexample.bash now uses the appropriate 0-based vector, so this script shouldn't be necessary in the future.

SimOutDir=$SCRATCH/possum_example/output

outFiles=$( find $SimOutDir -iname "possum_*" -type f )

mkdir $SimOutDir/scratch

for f in $outFiles; do
    outnum=$( echo "$f" | perl -pe "s:.*/possum_(\d+):\1:" )
    let outnum--
    cp $f $SimOutDir/scratch/possum_$outnum
done

rm -f $SimOutDir/possum_*
mv $SimOutDir/scratch/possum* $SimOutDir
rmdir $SimOutDir/scratch
