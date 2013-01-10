pulse -i brain.nii.gz -o example_pulse --te=0.03 --tr=2.00 \
    --trslc=0.0665 --nx=58 --ny=58 --dx=0.0033 --dy=0.0033 \
    --maxG=0.055 --riset=0.00022 --bw=180000 \
    --numvol=37 --numslc=30 --slcthk=0.004 --zstart=0.034 \
    --seq=epi --slcdir=z+ --readdir=x+ \
    --phasedir=y+ --gap=0.0 -v --cover=100 --angle=90
