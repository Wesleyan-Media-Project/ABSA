import pandas as pd
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.feature_extraction.text import TfidfTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.pipeline import Pipeline
from sklearn import metrics
from joblib import dump, load
from pyarrow import parquet as pq

# Input data
path_prepared = "../../data/fb2022_prepared_for_ABSA.parquet"
path_model = '../../train/models/trained_absa_rf.joblib'
# Output data
path_predictions = '../../data/fb2022_ABSA_pred.csv.gz'


# Inference on the fb22 dataset
df_inf = df_inf = pq.read_table(path_prepared).to_pandas()
text_clf = load(path_model)
predicted = text_clf.predict(df_inf['text'])

df_inf['predicted_sentiment'] = predicted

# Save without text column
df_inf = df_inf.drop(columns = 'text')
df_inf.to_csv(path_predictions, index = False)
