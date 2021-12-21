#!/bin/bash
printf "\n---------------------------- Executing contribution numbering test -----------------------------------.\n" 
lualatex --interaction=batchmode $1/test.tex
mv test.aux $1
mv test.log $1
mv test.pdf $1
mv xmp_metadata.xml $1
cmp --silent $1/xmp_metadata.xml $1/xmp_metadata_expected.xml && 
printf "\n\033[0;32m----------------------------### contribution numbering test PASS: XMP as expected! ###----------------------------------------\033[0m\n" || 
printf "\n\033[0;31m----------------------------### contribution numbering test FAIL: XMP not as expected! ###------------------------------------\033[0m\n"