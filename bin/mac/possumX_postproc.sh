#!/bin/sh

#   POSSUM
#
#   Ivana Drobnjak & Mark Jenkinson, FMRIB Analysis Group
#
#   Copyright (C) 2005-2007 University of Oxford
#
#   Part of FSL - FMRIB's Software Library
#   http://www.fmrib.ox.ac.uk/fsl
#   fsl@fmrib.ox.ac.uk
#   
#   Developed at FMRIB (Oxford Centre for Functional Magnetic Resonance
#   Imaging of the Brain), Department of Clinical Neurology, Oxford
#   University, Oxford, UK
#   
#   
#   LICENCE
#   
#   FMRIB Software Library, Release 5.0 (c) 2012, The University of
#   Oxford (the "Software")
#   
#   The Software remains the property of the University of Oxford ("the
#   University").
#   
#   The Software is distributed "AS IS" under this Licence solely for
#   non-commercial use in the hope that it will be useful, but in order
#   that the University as a charitable foundation protects its assets for
#   the benefit of its educational and research purposes, the University
#   makes clear that no condition is made or to be implied, nor is any
#   warranty given or to be implied, as to the accuracy of the Software,
#   or that it will be suitable for any particular purpose or for use
#   under any specific conditions. Furthermore, the University disclaims
#   all responsibility for the use which is made of the Software. It
#   further disclaims any liability for the outcomes arising from using
#   the Software.
#   
#   The Licensee agrees to indemnify the University and hold the
#   University harmless from and against any and all claims, damages and
#   liabilities asserted by third parties (including claims for
#   negligence) which arise directly or indirectly from the use of the
#   Software or the sale of any products based on the Software.
#   
#   No part of the Software may be reproduced, modified, transmitted or
#   transferred in any form or by any means, electronic or mechanical,
#   without the express permission of the University. The permission of
#   the University is not required if the said reproduction, modification,
#   transmission or transference is done without financial return, the
#   conditions of this Licence are imposed upon the receiver of the
#   product, and all original and amended source code is included in any
#   transmitted product. You may be held legally responsible for any
#   copyright infringement that is caused or encouraged by your failure to
#   abide by these terms and conditions.
#   
#   You are not permitted under this Licence to use this Software
#   commercially. Use for which any financial return is received shall be
#   defined as commercial use, and includes (1) integration of all or part
#   of the source code or the Software into a product for sale or license
#   by or on behalf of Licensee to third parties or (2) use of the
#   Software or any derivative of it for research with the final aim of
#   developing software products for sale or license to a third party or
#   (3) use of the Software or any derivative of it for research with the
#   final aim of developing non-software products for sale or license to a
#   third party, or (4) use of the Software to provide any service to an
#   external organisation for which payment is received. If you are
#   interested in using the Software commercially, please contact Isis
#   Innovation Limited ("Isis"), the technology transfer company of the
#   University, to negotiate a licence. Contact details are:
#   innovation@isis.ox.ac.uk quoting reference DE/9564.

subjdir=$1
nproc=$2

#$ -S /bin/sh
#$ -V
#$ -N p_possum
#$ -m ae

echo "POSSUMDIR (before)" $POSSUMDIR
if [ "${POSSUMDIR}" == "${FSLDEVDIR}" ] ; then
   echo "POSSUMDIR (during)" $POSSUMDIR
else
    export POSSUMDIR=$FSLDIR
fi
echo "POSSUMDIR (after)" $POSSUMDIR

run(){
 echo "$1" >> $2/possum.log
 $1 >> $2/possum.log 2>&1
 date >> $2/possum.log
}

echo Summing all signal from different proccesses into one total signal
run "${POSSUMDIR}/bin/possum_sum -i ${subjdir}/diff_proc/signal_proc_ -o ${subjdir}/signal -n $nproc " ${subjdir}

echo Converting the signal into the image
run "${POSSUMDIR}/bin/signal2image -i ${subjdir}/signal -o ${subjdir}/image -p ${subjdir}/pulse -a --homo " ${subjdir}

echo Removing intermediate files
if [ -e ${subjdir}/signal ]; then
      rm -rf ${subjdir}/diff_proc
fi

echo Adding noise
n=sigma
m=0
if [ -e ${subjdir}/noise ]; then
  n=`cat ${subjdir}/noise | awk '{print $1 }'`
  m=`cat ${subjdir}/noise | awk '{print $2 }'`
fi

if [ `${FSLDIR}/bin/imtest ${subjdir}/image_homo` -eq 1 ]; then
   imcp image_homo image_abs
fi

fslmaths ${subjdir}/image_abs -Tmean ${subjdir}/image_mean
P98=`fslstats ${subjdir}/image_mean -P 98`
P02=`fslstats ${subjdir}/image_mean -P 2`
tresh=`echo "0.1 * $P98 + 0.9 * $P02 "|bc -l`
fslmaths ${subjdir}/image_mean -thr $tresh ${subjdir}/image_mean
medint=`fslstats ${subjdir}/image_mean -P 50`
dim1=`fslval ${subjdir}/image_abs dim1`
if [ $n = "snr" ]; then
  snr=$m
  if [ $snr != 0 ]; then
     sigma=`echo " ${medint} / ( 2 * ${dim1} * ${snr} ) "| bc -l` #I worked this out ages ago.
     echo "sigma ${sigma} snr ${snr} medintensity ${medint}" > ${subjdir}/noise 
  else
     echo "snr  0" > ${subjdir}/noise
  fi
else
  sigma=$m
  if [ $sigma != 0 ]; then
     snr=`echo " ${medint} / ( 2 * ${dim1} * ${sigma} ) "| bc -l`
     echo "sigma $sigma snr $snr" > ${subjdir}/noise
  fi
fi
if [ $sigma != 0 ]; then
   mv ${subjdir}/signal ${subjdir}/signal_nonoise
   run "${POSSUMDIR}/bin/systemnoise --in=${subjdir}/signal_nonoise --out=${subjdir}/signal --sigma=${sigma}" $subjdir
fi
run "${POSSUMDIR}/bin/signal2image -i ${subjdir}/signal -o ${subjdir}/image -p ${subjdir}/pulse -a --homo" $subjdir
imrm ${subjdir}/image_mean

if [ `${FSLDIR}/bin/imtest ${subjdir}/image_homo` -eq 1 ]; then
   imrm image_abs
fi
