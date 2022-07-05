# CMRO2

## CMRO2calc2.xlsx

This spreadsheet will calculate everything you want (PNA, Hct, T1b, HbT, CSvO2, OEF, and CMRO2)

T1b calculation is based on PNA (days between DOB and Scan) from data extracted from https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3984444/ (see below)

Hct is calculated based on https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3984444/ where Hct = (1/T1b - 0.41) / 0.38

Hbt = Hct / (3*0.0165)

CSvO2 = 1 - (Chi_blood - (Chi_ox * Hct)) / (Chi_do*Hct)

where: Chi_ox = -0.376991118430775
and Chi_do = 2.63893782901543

OEF = CSaO2 - CSvO2

CMRO2 = CBF * OEF * Hbt

## JillDeVis_Impact_of_neonate_haematocrit.csv

These values were taken from the green points on Figure 2 of https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3984444/ (see below) using WebPlotDigitizer (http://weberlab.wikidot.com/webplotdigitizer)

## T1b from PNA.ipynb

Jupyter Notebook of R, finding the relation between T1b and PNA from JillDeVis_Impact_of_neonate_haematocrit.csv
T1b = 2.07558 - 0.00205*PNA

## Pipeline.sh

End to end pipeline for processing neonatal MRI data for CMRO2 calculations

The pipeline will organize raw DICOM data into the BIDS format, run the dHCP pipeline, create inidividual tissue masks, process SWI/R2*, and process ASL and QSM data

### Set-up

Prior to running the pipeline, there are a number of dependencies that will need to be installed and set-up

* [dcm2niix](https://github.com/rordenlab/dcm2niix.git)
* [dcm2bids](https://github.com/UNFmontreal/Dcm2Bids.git)
* [FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation) 
* [ANTS](https://github.com/ANTsX/ANTs.git)
* [Docker](https://docs.docker.com/get-docker/)
* [dHCP pipeline](https://github.com/BioMedIA/dhcp-structural-pipeline.git)
* Python
* MATLAB

The following github repos will also need to be downloaded

* [CBF](https://github.com/WeberLab/BCCHR_ASL.git)
* [QSM](https://github.com/WeberLab/QSMauto.git)
* [MATLAB Toolbox for QSM](https://github.com/kamesy/QSM.m.git)

At the beginning of the pipeline, change the paths of the following variables in `pipeline.sh` to their respective directory:

`$maindir, $qsmscript, $juliascript, $cbfscript, $cbftissue_script` 

### Input Requirements

The pipeline takes in a TSV file with 11 variables and will output another TSV file with 30 variables

TSV input file requirements include Subject ID, PMA, DICOM folder numbers for T1W, T2W, ASL, DTI Blip-up, DTI Blip-down, and QSM scans, HCT value, CSaO2 value, and thread number

### Running the pipeline
 cd into the directory with the pipeline and run the pipeline using the following code

`./pipeline.sh -f /full/path/of/input/tsv/file`

