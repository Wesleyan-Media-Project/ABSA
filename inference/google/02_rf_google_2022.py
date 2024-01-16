import pandas as pd
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.feature_extraction.text import TfidfTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.pipeline import Pipeline
from sklearn import metrics
from joblib import dump, load
import pickle

# Input data
path_prepared_google_2022 = "../../data/google2022_prepared_for_ABSA.csv"
path_model = '../../train/models/trained_absa_rf_2022.joblib'
# Output data
path_predictions = './data/google_2022_ABSA_pred.csv.gz'

# Inference on the Google 2020 dataset
df_inf = pd.read_csv(path_prepared_google_2022)
text_clf = load(path_model)
predictedgoogle_2022 = text_clf.predict(df_inf['text'])

df_inf['predicted_sentiment'] = predictedgoogle_2022

# Save without text column
df_inf = df_inf.drop(columns = 'text')
df_inf.to_csv(path_predictions, index = False)
