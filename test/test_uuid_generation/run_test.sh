#!/bin/bash
printf "\n---------------------------- Executing uuid generation test -----------------------------------.\n" 
lualatex --interaction=batchmode $1/test.tex
compile_success=$?
mv test.aux $1
mv test.log $1
mv test.pdf $1
mv test.xmp_metadata.xml $1
if [ $compile_success -eq 1 ]; then
    printf "\n\033[0;31m----------------------------### uuid generation test FAIL: Could not compile TeX file! ###------------------------------------\033[0m\n"  
    exit 1
fi
echo "$(head -1 $1/test.xmp_metadata.xml)"
echo "$(head -1 $1/xmp_metadata_expected.xml)"
# the headers are not equal
if [[ "$(head -1 $1/test.xmp_metadata.xml)" != "$(head -1 $1/xmp_metadata_expected.xml)" ]]; then
    printf "\n\033[0;32m----------------------------### uuid generation test PASS: New UUID generated! ###----------------------------------------\033[0m\n"
else
    printf "\n\033[0;31m----------------------------### uuid generation test FAIL: No new UUID generated! ###------------------------------------\033[0m\n"
    exit 1
fi