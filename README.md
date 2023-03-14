# ABSA

Pipeline verified as of 2022/06/21

ABSA results for the 1.18m dataset can be found in data/118m_ABSA_pred.csv

### Dependencies
Some scripts run in a Python environment require the following packages:
- pandas
- sklearn.feature_extraction.text
- sklearn.ensemble (requires `RandomForestClassifier` and `Pipeline` )
- sklearn
- joblib

In addition, some parts of the code require R to be installed, along with the following R libraries: 
- data.table
- tidyr
- stringi
- stringr
- dplyr

Other repositories that are needed:
- [entity_linking_2022](https://github.com/Wesleyan-Media-Project/entity_linking_2022)
- [datasets](https://github.com/Wesleyan-Media-Project/datasets)
- [entity_linking](https://github.com/Wesleyan-Media-Project/entity_linking)
