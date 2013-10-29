#!/bin/bash
#
dim=3 # image dimensionality
AP="" # /home/yourself/code/ANTS/bin/bin/  # path to ANTs binaries
ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=4  # controls multi-threading
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS
if [[ $# -lt 4 ]] ; then 
echo usage is 
echo $0 fixed.nii.gz moving.nii.gz fixed_landmark_image.nii.gz  moving_landmark_image.nii.gz
echo  where  x_landmark_image.nii.gz is binary 
exit
fi
f=$1 
m=$2    # fixed and moving image file names
flm=$3
mlm=$4
if [[ ! -s $f ]] ; then echo no fixed $f ; exit; fi
if [[ ! -s $m ]] ; then echo no moving $m ;exit; fi
if [[ ! -s $flm ]] ; then echo no fixed landmark $flm ; exit; fi
if [[ ! -s $mlm ]] ; then echo no moving landmark $mlm ;exit; fi
reg=${AP}antsRegistration           # path to antsRegistration
its=10000x111110x3
percentage=0.3
syn="100x100x50,-0.01,5"
nm=./landmark_ex   # construct output prefix
ImageMath 3 ${nm}_mask1.nii.gz  MD  $flm 50
ImageMath 3 ${nm}_mask2.nii.gz  MD  $mlm 50
MultiplyImages 3 ${nm}_mask1.nii.gz $f ${nm}_masked1.nii.gz
MultiplyImages 3 ${nm}_mask2.nii.gz $m ${nm}_masked2.nii.gz
imgs="  ${nm}_masked1.nii.gz, ${nm}_masked2.nii.gz "
$reg -d $dim -r [ $flm, $mlm ,1]  \
                        -m mattes[ $imgs  , 1 , 32 ] \
                         -t affine[ 0.1 ] \
                         -c [$its,1.e-8,20]  \
                        -s 4x2x1vox  \
                        -f 3x2x1 -l 1 -u 1 -z 1   \
                        -m cc[  $imgs  , 1 , 2 ] \
                         -t syn[ 0.2, 3, 0 ] \
                         -c [50x30x0,1.e-8,20]  \
                        -s 4x2x1vox  \
                        -f 3x2x1 -l 1 -u 1 -z 1 -x ${nm}_mask1.nii.gz  \
                       -o [${nm},${nm}_diff.nii.gz,${nm}_inv.nii.gz]
