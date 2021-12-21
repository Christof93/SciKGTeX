#!/bin/bash
printf "\n---------------------------- Executing wrong uri test -----------------------------------.\n" 
lualatex --interaction=batchmode $1/test.tex
mv test.aux $1
mv test.log $1
mv test.pdf $1
mv xmp_metadata.xml $1
if cmp --silent $1/xmp_metadata.xml $1/xmp_metadata_expected.xml; then
    :
else
    printf "\n\033[0;31m----------------------------### wrong uri test FAIL: XMP not as expected! ###------------------------------------\033[0m\n" exit 0
    exit 0
fi

if grep -q "Package orkg4latex Warning: Method ORKGaddproperty: Too many arguments." $1/test.log; then
    printf "\n\033[0;32m----------------------------### wrong uri test PASS: XMP as expected! Successful warning! ###----------------------------------------\033[0m\n"
else
    printf "\n\033[0;31m----------------------------### wrong uri test FAIL: No warning produced! ###------------------------------------\033[0m\n"
fi