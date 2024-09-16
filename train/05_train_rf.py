import pandas as pd
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.feature_extraction.text import TfidfTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.pipeline import Pipeline
from sklearn import metrics
from joblib import dump, load

# Input data
path_absa_train_data = 'data/generic_separate_absa_train.csv'
path_absa_test_data = 'data/generic_separate_absa_test.csv'
# Output data
path_model = 'train/models/trained_absa_rf.joblib'

#load data
df_train = pd.read_csv(path_absa_train_data, encoding='ISO-8859-1')
df_test = pd.read_csv(path_absa_test_data, encoding='ISO-8859-1')

# Random Forest
text_clf = Pipeline([('vect', CountVectorizer()),
                     ('tfidf', TfidfTransformer()),
                     ('clf', RandomForestClassifier(random_state=123)),
])
# Train & test performance
text_clf.fit(df_train['text'], df_train['TONE'])
predicted = text_clf.predict(df_test['text'])
print(metrics.classification_report(df_test['TONE'], predicted))

# Metrics
#              precision    recall  f1-score   support
#
#          -1       0.77      0.81      0.79      2382
#           0       0.75      0.21      0.33       201
#           1       0.87      0.87      0.87      4075
#
#    accuracy                           0.83      6658
#   macro avg       0.80      0.63      0.66      6658
#weighted avg       0.83      0.83      0.82      6658

# Save model to disk
dump(text_clf, path_model)
