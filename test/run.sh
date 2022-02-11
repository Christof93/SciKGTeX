#!/bin/bash
cp metasci.sty test
cp metasci.lua test
cd test

if [ ! -z $1 ] 
then :
    ./$1/run_test.sh $1
else :
    for folder in test*; do
        ./$folder/run_test.sh $folder
    done
fi

