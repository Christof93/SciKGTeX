#!/bin/bash
cp scikgtex.sty test
cp scikgtex.lua test
cd test
printf '%s\n' "pdf.setcompresslevel(0)" "$(cat scikgtex.lua)" > scikgtex.lua
returncode=0
if [ ! -z $1 ] 
then :
    ./$1/run_test.sh $1
else :
    for folder in test*; do
        ./$folder/run_test.sh $folder
        if [ $? -eq 1 ]; then
            return_code=1 
        fi
    done
fi
exit $returncode

