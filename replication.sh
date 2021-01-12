#!/bin/bash

#Re-estimate GANs
python3 gan_estimation/gan_baseline.py
python3 gan_estimation/gan_robust.py

#Re-calculate ATTs on subsamples
#Rscript Jonas TODO

#Create tables and figures
python3 exhibits.py > tables/tables1.txt
Rscript exhibits.R > tables/tables2.txt
