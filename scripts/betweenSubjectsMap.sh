#!/bin/bash
# this will map the label in the f image to the m subject 
# at all time points 
dim=3 # image dimensionality
AP="" # /home/yourself/code/ANTS/bin/bin/  # path to ANTs binaries
ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=2  # controls multi-threading
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS
f=$1      # 4D template image
mask=$2   # 4D template label 
m=$3      # 4D moving image to be labeled 
if [[ ! -s $f ]] ; then echo no fixed $f ; exit; fi
if [[ ! -s $mask ]] ; then echo no mask $mask ;exit; fi
if [[ ! -s ${m} ]] ; then 
  echo usage is 
  echo $0 fixed4D fixed4Dmask moving4Dimage 
  exit
fi
./scripts/makeSubjectTemplate.sh $f $mask 
./scripts/makeSubjectTemplate.sh $m
fnm=` basename $f `
fnm=` echo $fnm | cut -d '.' -f  1 `
mnm=` basename $m `
mnm=` echo $mnm | cut -d '.' -f  1 `
nm=output/ants_${mnm}_${fnm} 
mkdir -p ${nm}
outnm=${nm}/ants
reg=${AP}antsRegistration           # path to antsRegistration
Lval=1
favg=output/ants${fnm}/ants${fnm}_avg.nii.gz 
favgm=output/ants${fnm}/ants${fnm}_avg_seg.nii.gz 
mavg=output/ants${mnm}/ants${mnm}_avg.nii.gz 
if [[ ! -s $favg ]] ; then 
  echo favg is missing 
  exit 1
fi
if [[ ! -s $favgm ]] ; then 
  echo favgm is missing 
  exit 1
fi
if [[ ! -s $mavg ]] ; then 
  echo mavg is missing 
  exit 1
fi
fo=${outnm}f.nii.gz
mo=${outnm}m.nii.gz
N3BiasFieldCorrection 3 $favg $fo 4 
N3BiasFieldCorrection 3 $mavg $mo 4 
N3BiasFieldCorrection 3 $fo $fo 2 
N3BiasFieldCorrection 3 $mo $mo 2 
ImageMath 3 $fo TruncateImageIntensity $fo 0.05 0.95 128 
ImageMath 3 $mo TruncateImageIntensity $mo 0.05 0.95 128
ImageMath 3 $fo Normalize $fo  
ImageMath 3 $mo Normalize $mo  
ImageMath 3 ${outnm}fg.nii.gz Grad $fo 1 
ImageMath 3 ${outnm}mg.nii.gz Grad $mo 1 
ThresholdImage 3 $fo ${outnm}fseg.nii.gz Otsu 3 
ThresholdImage 3 $mo ${outnm}mseg.nii.gz Otsu 3 
ImageMath 3 ${outnm}mask.nii.gz MD $favgm  25 
ImageMath 3 ${outnm}mask.nii.gz ME ${outnm}mask.nii.gz  20
mystep=0.1
init=1
$reg -d $dim  -r [ $fo, $mo, $init ] \
    -m  meansquares[ $fo , $mo , 1 , 32, random, 0.2 ] \
    -t translation[ .1 ] \
    -c [ 500x500x100x100x33, 1.e-7, 3 ]  \
    -s 6x4x2x1x0mm  \
    -f 16x8x4x2x1 -l $Lval -u 1 -z 1     \
    -m  meansquares[ $fo , $mo , 1 , 32, random, 0.2 ] \
    -t affine[ .1 ] \
    -c [ 500x100x33, 1.e-7, 3 ]  \
    -s 2x1x0mm  \
    -f 4x2x1 -l $Lval -u 1 -z 1   \
    -m meansquares[ $fo                 , $mo , 1 , 2 ] \
    -t SyN[ .2, 3, 0.0 ] \
    -c [ 20x20x20x0, 0, 5 ]  \
    -s 2x1.5x1x0mm  \
    -f 2x2x2x1 -l $Lval -u 1 -z 1     -x [ ${outnm}mask.nii.gz   ] \
    -o [${outnm},${outnm}diff.nii.gz,${outnm}inv.nii.gz]

antsApplyTransforms -d 3 -i $favgm -r $mo -n NearestNeighbor -t [${outnm}0GenericAffine.mat,1] -t ${outnm}1InverseWarp.nii.gz -o ${outnm}_labeled.nii.gz

