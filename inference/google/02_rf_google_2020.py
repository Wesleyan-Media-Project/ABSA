import pandas as pd
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.feature_extraction.text import TfidfTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.pipeline import Pipeline
from sklearn import metrics
from joblib import dump, load

# Input data
path_prepared_google_2020 = "../../data/google2020_prepared_for_ABSA.csv"
path_model = '../../train/models/trained_absa_rf.joblib'
# Output data
path_predictions = '../../data/google_2020_ABSA_pred.csv.gz'


# Inference on the Google 2020 dataset
df_inf = pd.read_csv(path_prepared_google_2020)
text_clf = load(path_model)
predictedgoogle_2020 = text_clf.predict(df_inf['text'])

df_inf['predicted_sentiment'] = predictedgoogle_2020

# Save without text column
df_inf = df_inf.drop(columns = 'text')
df_inf.to_csv(path_predictions, index = False)
