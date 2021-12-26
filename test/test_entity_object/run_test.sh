#!/bin/bash
printf "\n---------------------------- Executing entity as object test -----------------------------------.\n" 
lualatex --interaction=batchmode $1/test.tex
mv test.aux $1
mv test.log $1
mv test.pdf $1
mv xmp_metadata.xml $1
if cmp --silent $1/xmp_metadata.xml $1/xmp_metadata_expected.xml; then
    :
else
    printf "\n\033[0;31m----------------------------### entity as object test FAIL: XMP not as expected! ###------------------------------------\033[0m\n" exit 0
    exit 0
fi

printf "\n\033[0;32m----------------------------### entity as object test PASS: XMP as expected! Successful warning! ###----------------------------------------\033[0m\n"