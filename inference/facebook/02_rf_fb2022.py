import pandas as pd
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.feature_extraction.text import TfidfTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.pipeline import Pipeline
from sklearn import metrics
from joblib import dump, load

# Input data
path_prepared = "data/fb2022_prepared_for_ABSA.csv"
path_model = 'train/models/trained_absa_rf.joblib'
# Output data
path_predictions = 'data/fb2022_ABSA_pred.csv.gz'


# Inference on the fb22 dataset
df_inf = pd.read_csv(path_prepared)
text_clf = load(path_model)
predicted = text_clf.predict(df_inf['text'])

df_inf['predicted_sentiment'] = predicted

# Exclude George Washington from results because entity linking might interpret Washington DC as George Washington
df_inf = df_inf[df_inf['text_detected_entities'] != 'WMPID5206']

# Save without text column
df_inf = df_inf.drop(columns = 'text')
df_inf.to_csv(path_predictions, index = False)
