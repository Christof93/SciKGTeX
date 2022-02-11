#!/bin/bash
printf "\n---------------------------- Executing peculiar property definition test -----------------------------------.\n" 
echo '<?xpacket begin="?" id="48fdc517-5814-4d0c-cd03-0c296941c6"?>\n' > test.xmp_metadata.xml
lualatex --interaction=batchmode $1/test.tex
mv test.aux $1
mv test.log $1
mv test.pdf $1
mv test.xmp_metadata.xml $1
if cmp --silent $1/test.xmp_metadata.xml $1/xmp_metadata_expected.xml; then
    :
else
    printf "\n\033[0;31m----------------------------### peculiar property definition test FAIL: XMP not as expected! ###------------------------------------\033[0m\n"
    exit 0
fi

if grep -q "LaTeX Error: Command \\\section already defined" $1/test.log; then
    printf "\n\033[0;32m----------------------------### peculiar property definition test PASS: XMP as expected! Successful error! ###----------------------------------------\033[0m\n"
else
    printf "\n\033[0;31m----------------------------### peculiar property definition test FAIL: No error produced! ###------------------------------------\033[0m\n"
fi