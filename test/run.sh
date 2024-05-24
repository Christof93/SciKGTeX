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
        ./$folder/run_test.sh $folder > /dev/null
        code=$?
        if [ $code -ne 0 ]; then
            printf "\n\033[0;31m$folder FAILED with code $code. \033[0m\n"
            returncode=1
        else
            printf "\033[0;32m.\033[0m"
        fi
    done
fi
echo "\nTests finished with exit code: $returncode"
exit $returncode

