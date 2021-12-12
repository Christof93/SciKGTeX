lualatex orkg4latex.dtx
cp orkg4latex.sty test
cp orkg4latex.lua test
cd test
#lualatex CrowdRE-VideoComments_v03_camera-ready.tex

for folder in test*; do
    echo "\n---------------------------- Executing tests in folder ${folder} -----------------------------------.\n" 
    lualatex ${folder}/test.tex
    mv test.* ${folder}
    mv xmp_metadata.xml ${folder}
done