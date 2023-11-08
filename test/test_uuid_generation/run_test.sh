#!/bin/bash
printf "\n---------------------------- Executing uuid generation test -----------------------------------.\n" 
# Run twice in the same second
lualatex --interaction=batchmode $1/test1.tex &
lualatex --interaction=batchmode $1/test2.tex &
wait
compile_success=$?
mv test1.aux $1
mv test1.log $1
mv test1.pdf $1
mv test1.xmp_metadata.xml $1
mv test2.aux $1
mv test2.log $1
mv test2.pdf $1
mv test2.xmp_metadata.xml $1
if [ $compile_success -eq 1 ]; then
    printf "\n\033[0;31m----------------------------### uuid generation test FAIL: Could not compile TeX file! ###------------------------------------\033[0m\n"  
    exit 1
fi
echo "test1 uuid: $(head -1 $1/test1.xmp_metadata.xml)"
echo "test2 uuid: $(head -1 $1/test2.xmp_metadata.xml)"
echo "previous uuid: $(head -1 $1/xmp_metadata_expected.xml)"
# the headers are not equal
if [[ "$(head -1 $1/test2.xmp_metadata.xml)" != "$(head -1 $1/test1.xmp_metadata.xml)" ]] &&
   [[ "$(head -1 $1/test1.xmp_metadata.xml)" != "$(head -1 $1/xmp_metadata_expected.xml)" ]] &&
   [[ "$(head -1 $1/test2.xmp_metadata.xml)" != "$(head -1 $1/xmp_metadata_expected.xml)" ]]; then
    printf "\n\033[0;32m----------------------------### uuid generation test PASS: New UUID generated! ###----------------------------------------\033[0m\n"
else
    printf "\n\033[0;31m----------------------------### uuid generation test FAIL: No new UUID generated! ###------------------------------------\033[0m\n"
    exit 1
fi