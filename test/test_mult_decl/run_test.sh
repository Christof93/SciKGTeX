#!/bin/bash
printf "\n---------------------------- Executing multiple declarations test -----------------------------------.\n" 
echo '<?xpacket begin="?" id="48fdc517-5814-4d0c-cd03-0c296941c6"?>\n' > test.xmp_metadata.xml
lualatex --interaction=batchmode $1/test.tex
compile_success=$?
mv test.aux $1
mv test.log $1
mv test.pdf $1
mv test.xmp_metadata.xml $1
if [ $compile_success -eq 1 ]; then
    printf "\n\033[0;31m----------------------------### multiple declarations test FAIL: Could not compile TeX file! ###------------------------------------\033[0m\n"  
    exit 1
fi
if cmp --silent $1/test.xmp_metadata.xml $1/xmp_metadata_expected.xml; then
    :
else
    printf "\n\033[0;31m----------------------------### multiple declarations test FAIL: XMP not as expected! ###------------------------------------\033[0m\n"
    exit 2
fi

if grep -q "Warning: Method newpropertycommand: Repeated definition." $1/test.log; then
    :
else
    printf "\n\033[0;31m----------------------------### multiple declarations test FAIL: No warning produced! ###------------------------------------\033[0m\n"
    exit 3
fi

if grep -q "Package SciKGTeX Warning: The property 'unknown_contribution_type' does not" $1/test.log; then
    :
else
    printf "\n\033[0;31m----------------------------### multiple declarations test FAIL: No warning produced! ###------------------------------------\033[0m\n"
    exit 4
fi

if grep -q "Package SciKGTeX Warning: The property 'custom_contribution_type' does not" $1/test.log; then
    printf "\n\033[0;31m----------------------------### multiple declarations test FAIL: An unwarranted warning was produced! ###------------------------------------\033[0m\n"
    exit 5
else
    printf "\n\033[0;32m----------------------------### multiple declarations test PASS: XMP as expected! Successful warning! ###----------------------------------------\033[0m\n"
fi