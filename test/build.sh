lualatex orkg4latex.dtx
cp orkg4latex.sty test
cp orkg4latex.lua test
cd test

for folder in test*; do
    echo "\n---------------------------- Executing tests in folder ${folder} -----------------------------------.\n" 
    lualatex --interaction=batchmode ${folder}/test.tex
    mv test.* ${folder}
    mv xmp_metadata.xml ${folder}
    cmp --silent ${folder}/xmp_metadata.xml ${folder}/xmp_metadata_expected.xml && 
    echo "\n\033[0;32m----------------------------### ${folder} PASS: XMP as expected! ###----------------------------------------\033[0m\n" || 
    echo "\n\033[0;31m----------------------------### ${folder} FAIL: XMP not as expected! ###------------------------------------\033[0m\n" 
done