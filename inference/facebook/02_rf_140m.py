import pandas as pd
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.feature_extraction.text import TfidfTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.pipeline import Pipeline
from sklearn import metrics
from joblib import dump, load

# Input data
path_prepared_140m = "../../data/140m_prepared_for_ABSA.csv.gz"
path_model = '../../train/models/trained_absa_rf.joblib'
# Output data
path_predictions = '../../data/140m_ABSA_pred.csv.gz'


# Inference on the 1.40m dataset
df_inf = pd.read_csv(path_prepared_140m)
text_clf = load(path_model)
predicted140m = text_clf.predict(df_inf['text'])

df_inf['predicted_sentiment'] = predicted140m

# Save without text column
df_inf = df_inf.drop(columns = 'text')
df_inf.to_csv(path_predictions, index = False)
