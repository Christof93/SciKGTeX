#!/bin/bash
printf "\n---------------------------- Executing entity as object test -----------------------------------.\n" 
echo '<?xpacket begin="?" id="48fdc517-5814-4d0c-cd03-0c296941c6"?>\n' > test.xmp_metadata.xml
lualatex --interaction=batchmode $1/test.tex
if [ $? -eq 1 ]; then
    printf "\n\033[0;31m----------------------------### entity as object test FAIL: Could not compile TeX file! ###------------------------------------\033[0m\n"  
    exit
fi
mv test.aux $1
mv test.log $1
mv test.pdf $1
mv test.xmp_metadata.xml $1
if cmp --silent $1/test.xmp_metadata.xml $1/xmp_metadata_expected.xml; then
    :
else
    printf "\n\033[0;31m----------------------------### entity as object test FAIL: XMP not as expected! ###------------------------------------\033[0m\n" exit 0
    exit 0
fi

printf "\n\033[0;32m----------------------------### entity as object test PASS: XMP as expected! ###----------------------------------------\033[0m\n"