#!/bin/bash
cp scikgtex.sty test
cp scikgtex.lua test
cd test
rm test.out
printf '%s\n' "pdf.setcompresslevel(0)" "$(cat scikgtex.lua)" > scikgtex.lua
returncode=0
if [ ! -z $1 ] 
then :
    ./$1/run_test.sh $1
    returncode=$?
else :
    for folder in test*; do
        ./$folder/run_test.sh $folder
        if [ $? -ne 0 ]; then
            echo 'TEST FAILED...'
            returncode=1 
        fi
    done
fi
echo "Tests finished with exit code: $returncode"
exit $returncode

