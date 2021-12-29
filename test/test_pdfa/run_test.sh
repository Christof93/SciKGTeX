#!/bin/bash
printf "\n---------------------------- Executing simple test -----------------------------------.\n" 
lualatex --interaction=batchmode $1/test.tex
mv test.aux $1
mv test.log $1
mv test.pdf $1