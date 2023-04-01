import pandas as pd
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.feature_extraction.text import TfidfTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.pipeline import Pipeline
from sklearn import metrics
from joblib import dump, load

# Input data
path_absa_train_data = '../data/generic_separate_absa_train.csv'
path_absa_test_data = '../data/generic_separate_absa_test.csv'
# Output data
path_model = 'models/trained_absa_rf.joblib'

#load data
df_train = pd.read_csv(path_absa_train_data)
df_test = pd.read_csv(path_absa_test_data)

# Random Forest
text_clf = Pipeline([('vect', CountVectorizer()),
                     ('tfidf', TfidfTransformer()),
                     ('clf', RandomForestClassifier(random_state=123)),
])
# Train & test performance
text_clf.fit(df_train['text'], df_train['TONE'])
predicted = text_clf.predict(df_test['text'])
print(metrics.classification_report(df_test['TONE'], predicted))

#               precision    recall  f1-score   support
# 
#           -1       0.79      0.91      0.84      1337
#            0       0.78      0.28      0.41       143
#            1       0.87      0.80      0.83      1395
# 
#     accuracy                           0.82      2875
#    macro avg       0.81      0.66      0.70      2875
# weighted avg       0.83      0.82      0.82      2875

# Save model to disk
dump(text_clf, path_model)
