#!/bin/bash
printf "\n---------------------------- Executing nested commands test -----------------------------------.\n" 
echo '<?xpacket begin="?" id="48fdc517-5814-4d0c-cd03-0c296941c6"?>\n' > test.xmp_metadata.xml
lualatex --interaction=batchmode $1/test.tex
compile_success=$?
mv test.aux $1
mv test.log $1
mv test.pdf $1
mv test.xmp_metadata.xml $1
if [ $compile_success -eq 1 ]; then
    printf "\n\033[0;31m----------------------------### nested commands test FAIL: Could not compile TeX file! ###------------------------------------\033[0m\n"  
    exit 1
fi
if cmp --silent $1/test.xmp_metadata.xml $1/xmp_metadata_expected.xml; then 
    printf "\n\033[0;32m----------------------------### nested commands test PASS: XMP as expected! ###----------------------------------------\033[0m\n";
else
    printf "\n\033[0;31m----------------------------### nested commands test FAIL: XMP not as expected! ###------------------------------------\033[0m\n";
    exit 2;
fi