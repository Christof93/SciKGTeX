#!/bin/bash
printf "\n---------------------------- Executing uuid generation test -----------------------------------.\n" 
lualatex --interaction=batchmode $1/test.tex
mv test.aux $1
mv test.log $1
mv test.pdf $1
mv test.xmp_metadata.xml $1

if [ "$x" = "valid" ]; then
    :
else
    printf "\n\033[0;31m----------------------------### uuid generation test FAIL: No new UUID generated! ###------------------------------------\033[0m\n"
    exit 0
fi

if cmp --silent $1/test.xmp_metadata.xml $1/xmp_metadata_expected.xml; then
    printf "\n\033[0;32m----------------------------### uuid generation test PASS: New UUID generated! ###----------------------------------------\033[0m\n"
else
    printf "\n\033[0;31m----------------------------### uuid generation test FAIL: XMP not as expected! ###------------------------------------\033[0m\n"
