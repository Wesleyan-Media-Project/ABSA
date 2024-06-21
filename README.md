# CREATIVE --- Aspect Based Sentiment Analysis (ABSA)

Welcome! This repo contains scripts for predicting sentiment towards entities within political ads using Aspect-Based Sentiment Analysis (ABSA).

This repo is part of the Cross-platform Election Advertising Transparency initiative ([CREATIVE](https://www.creativewmp.com/)) project. CREATIVE is an academic research project that has the goal of providing the public with analysis tools for more transparency of political ads across online platforms. In particular, CREATIVE provides cross-platform integration and standardization of political ads collected from Google and Facebook. CREATIVE is a joint project of the [Wesleyan Media Project (WMP)](https://mediaproject.wesleyan.edu/) and the [privacy-tech-lab](https://privacytechlab.org/) at [Wesleyan University](https://www.wesleyan.edu).

To analyze the different dimensions of political ad transparency we have developed an analysis pipeline. The scripts in this repo are part of the Data Classification step in our pipeline. ![A picture of the repo pipeline with this repo highlighted](CREATIVE_step3_032524.png)

## Table of Contents

[1. Introduction](#1-introduction)  
[2. Data](#2-data)  
[3. Setup](#3-setup)  
[4. Thank You!](#4-thank-you)

## 1. Introduction

This repo contains scripts for the Aspect-Based Sentiment Analysis (ABSA) to predict sentiment (1: positive, 0: neutral, -1: negative) towards entities identified by the [entity linker](https://github.com/Wesleyan-Media-Project/entity_linking) (see [here for the 2022 entity linker](https://github.com/Wesleyan-Media-Project/entity_linking_2022)). Each identified entity mention has its own ABSA prediction. Thus, it is (theoretically) possible for an ad to discuss a candidate positively in one place and negatively in another. The model used in this repo is a random forest classifier.

## 2. Data

The input data for the ABSA classification come from the entity linking. Thus, you need to grab the following files in order to run our scripts:

- For [Facebook 2022](https://github.com/Wesleyan-Media-Project/entity_linking_2022/facebook/data/entity_linking_results_fb22.csv.gz)
- For [Google 2022](https://github.com/Wesleyan-Media-Project/entity_linking_2022/google/data/entity_linking_results_google_2022.csv.gz) 

All the output data for the ABSA results are stored in the `data` folder. They are in `csv.gz` and `csv` format. The training model is stored in the train/models folder in `joblib` format.

## 3. Setup

The scripts are numbered in the order in which they should be run. Scripts that directly depend on one another are ordered sequentially. Scripts with the same number are alternatives; usually they are the same scripts on different data. There are separate folders for Facebook and Google.

### 3.1 Requirements

The scripts are tested on on R 4.2, 4.3, 4.4 and Python 3.9, 3.10. The packages we used are described in requirements_r.txt and requirements_py.txt.

(ADD SETUP STEPS FOR R AND PYTHON)

### 3.2 Training

Note: If you want to use the pre-trained model we provide, you can find it [here](https://github.com/Wesleyan-Media-Project/ABSA/blob/main/train/models/trained_absa_rf.joblib).

To run the inference scripts, you need to first train a model for sentiment analysis. The script `train/01_prepare_separate_generic_absa.R` is used for this model training. The data you need to run this are:

- [`entity_linking/facebook/data/entity_linking_results_140m_notext_new.csv.gz`](https://github.com/Wesleyan-Media-Project/entity_linking/blob/main/facebook/data/entity_linking_results_140m_notext_new.csv.gz)
- [`fb_2020/fb_2020_140m_adid_text_clean.csv.gz`](INSERT FIGSHARE LINK ONCE READY)
- [`datasets/facebook/FBEL_2.0_cleanednoICR_041222.csv`](https://github.com/Wesleyan-Media-Project/datasets/blob/main/facebook/FBEL_2.0_cleanednoICR_041222.csv)
- [`datasets/candidates/face_url_candidate.csv`](https://github.com/Wesleyan-Media-Project/datasets/blob/main/candidates/face_url_candidate.csv)
- [`datasets/candidates/face_url_politician.csv`](https://github.com/Wesleyan-Media-Project/datasets/blob/main/candidates/face_url_politician.csv)

To train the model to detect sentiment even for entities that aren't seen (or rarely seen) in the training set, the data is set up as following: The specific name of the detected entity is replaced by `$T$` (this is the same way it works in [this](https://github.com/songyouwei/ABSA-PyTorch) repo). This way, the model learns that the output label is based on text that relates to the `$T$`. In theory, a neural-based classifier should be much better at this than a bag-of-words model, but in practice, the latter works well enough. We saw a big difference with a model that only learned and detected sentiment for Trump and Biden - the neural approach was much better here - but for a model targeted at any generic candidate, the bag of words model has results that are comparably good.

### 3.3 Inference

Once you have the model, you can run the inference scripts. These scripts are located [here for Facebook](https://github.com/Wesleyan-Media-Project/ABSA/tree/main/inference/facebook) and [here for Google](https://github.com/Wesleyan-Media-Project/ABSA/tree/main/inference/google). There are two main scripts for each. First, we prepare the data for the sentiment analysis and second, this prepared data is run trhough the trained model to produce the classification results.

## 4. Thank You

<p align="center"><strong>We would like to thank our supporters!</strong></p><br>

<p align="center">This material is based upon work supported by the National Science Foundation under Grant Numbers 2235006, 2235007, and 2235008.</p>

<p align="center" style="display: flex; justify-content: center; align-items: center;">
  <a href="https://www.nsf.gov/awardsearch/showAward?AWD_ID=2235006">
    <img class="img-fluid" src="nsf.png" height="150px" alt="National Science Foundation Logo">
  </a>
</p>

<p align="center">The Cross-Platform Election Advertising Transparency Initiative (CREATIVE) is a joint infrastructure project of the Wesleyan Media Project and privacy-tech-lab at Wesleyan University in Connecticut.

<p align="center" style="display: flex; justify-content: center; align-items: center;">
  <a href="https://www.creativewmp.com/">
    <img class="img-fluid" src="CREATIVE_logo.png"  width="220px" alt="CREATIVE Logo">
  </a>
</p>

<p align="center" style="display: flex; justify-content: center; align-items: center;">
  <a href="https://mediaproject.wesleyan.edu/">
    <img src="wmp-logo.png" width="218px" height="100px" alt="Wesleyan Media Project logo">
  </a>
</p>

<p align="center" style="display: flex; justify-content: center; align-items: center;">
  <a href="https://privacytechlab.org/" style="margin-right: 20px;">
    <img src="./plt_logo.png" width="200px" alt="privacy-tech-lab logo">
  </a>
</p>
