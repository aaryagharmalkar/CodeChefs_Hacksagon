import pickle

# Load vectorizer
with open("tfidf_vectorizer (1).pkl", "rb") as f:
    vectorizer = pickle.load(f)

# Load model
with open("dementia_model_cookie.pkl", "rb") as f:
    model = pickle.load(f)

# Sample input (Cookie Theft description)
text = "The boy is stealing cookies and the water is overflowing while the mother is distracted"

# Convert text → features
X = vectorizer.transform([text])

# Predict
prediction = model.predict(X)

# If model supports probabilities
if hasattr(model, "predict_proba"):
    prob = model.predict_proba(X)
    print("Confidence:", prob)

print("Prediction:", prediction)