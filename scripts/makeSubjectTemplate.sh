#!/bin/bash
#
dim=3 # image dimensionality
AP="" # /home/yourself/code/ANTS/bin/bin/  # path to ANTs binaries
ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=2  # controls multi-threading
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS
img=$1
lab=$2
if [[ ! -s $img ]] ; then 
  echo usage: $0 input4Dimage 
  exit 
fi
havelab=0
if [[ -s $lab ]] && [[ ${#lab} -gt 3 ]] ; then 
  havelab=1 
fi
nm=` basename $img `
nm=` echo $nm | cut -d '.' -f  1 `
nm=ants${nm}
mkdir -p output/${nm}
outpre=output/${nm}/${nm}
ntimepoints=` PrintHeader $img | grep Dimensions | cut -d , -f 4 | cut -d ']' -f 1 `
echo $nm $ntimepoints
nt=$(( $ntimepoints - 1 ))
for x in `seq -w 0 $nt `; do 
  if [[ ! -s ${outpre}_${x}_img.nii.gz  ]] ; then 
    ExtractSliceFromImage 4 $img ${outpre}_${x}_img.nii.gz 3 $x
    if [[ $havelab -eq 1  ]] ; then 
      ExtractSliceFromImage 4 $lab ${outpre}_${x}_seg.nii.gz 3 $x   
    fi
  fi  
done
f=${outpre}_avg.nii.gz
AverageImages 3 $f 1 ${outpre}_*_img.nii.gz 
for x in `seq -w 0 $nt `; do 
   m=${outpre}_${x}_img.nii.gz
   if [[ -s $m ]] && [[ ! -s ${outpre}_${x}_img0Warp.nii.gz ]] ; then 
     antsRegistration -d 3  \
	                -m meansquares[ $f, $m ] \
                        -t SyN[ .25, 3, 0.5 ] \
                        -c [ 10x10x0, 0, 5 ]  \
                        -s 2x1x0mm  \
                        -f 2x2x1 -l 1 -u 1 -z 1 \
	 -o [${outpre}_${x}_img, ${outpre}_${x}_imgw.nii.gz]
   fi 
   if [[ $havelab -eq 1 ]] && [[ -s ${outpre}_${x}_img0Warp.nii.gz ]] ; then
     m=${outpre}_${x}_seg.nii.gz
     mw=${outpre}_${x}_segw.nii.gz
     antsApplyTransforms -d 3 -i $m -o $mw -t ${outpre}_${x}_img0Warp.nii.gz -r $f -n NearestNeighbor
   fi
done 
AverageImages 3 $f 1 ${outpre}_*_imgw.nii.gz 
if [[ $havelab -eq 1 ]] ; then 
  ImageMath 3 ${outpre}_avg_seg.nii.gz MajorityVoting ${outpre}_*_segw.nii.gz
fi
#
# now we have a motion corrected dataset , a subject-specific template and its segmentation 
#
