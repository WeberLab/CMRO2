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
