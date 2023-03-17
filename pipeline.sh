#!/bin/bash

# Training on FB 2020
cd train/
Rscript --no-environ --no-save 01_prepare_separate_generic_absa.R
python 02_train_rf.py
# Inference on FB 2020
cd ../inference/facebook/
Rscript --no-environ --no-save 01_prepare_fb_2020.R
python 02_rf_140m.py