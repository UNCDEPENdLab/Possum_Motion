#!/bin/bash

#double the 150 activation for the "hold" approach to activation (where there is little interpolation from one TR to the next because the two volumes with identical activations are used to "hold" a value).

what="$1"
#echo "what: $what"

[ -z "$what" ] && echo "Did not specify what image to double. Pass as first parameter." && exit 1
[ ! -r "$what" ] && echo "File $what does not exist." && exit 1

cd $( dirname "$what" )

fslsplit "$what" tcat
mergecmd="fslmerge -tr $( remove_ext \"$what\" )_DOUBLE"
for f in $( ls tcat* | sort -n ); do
    mergecmd="$mergecmd $f $f" #double each image
done

mergecmd="$mergecmd 2.0"
echo "CMD: $mergecmd"
eval $mergecmd
rm -f tcat*
