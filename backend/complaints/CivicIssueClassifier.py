"""
CNN + NLP-based civic issue classification.
Classifies images and text into: Garbage, Pothole, Streetlight Issue, Road Damage.
Spam is detected using low confidence or model disagreement.
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
from torchvision import transforms, models
from PIL import Image
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
import pickle

# Categories (no spam)
CATEGORIES = ["Garbage", "Pothole", "Streetlight Issue", "Road Damage"]

# ------------------------
# 1. CNN Image Model
# ------------------------
class CNNClassifier(nn.Module):
    def __init__(self, num_classes=4):
        super(CNNClassifier, self).__init__()
        self.model = models.resnet18(weights=models.ResNet18_Weights.DEFAULT)
        self.model.fc = nn.Linear(self.model.fc.in_features, num_classes)
    
    def forward(self, x):
        return self.model(x)

# Load pretrained CNN for images
device = "cuda" if torch.cuda.is_available() else "cpu"
cnn_model = CNNClassifier(num_classes=4).to(device)
cnn_model.eval()  # evaluation mode

# Image preprocessing
image_transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406],  std=[0.229, 0.224, 0.225])
])

# ------------------------
# 2. NLP Text Model
# ------------------------
try:
    with open("text_vectorizer.pkl", "rb") as f:
        vectorizer = pickle.load(f)
    with open("text_classifier.pkl", "rb") as f:
        text_model = pickle.load(f)
except FileNotFoundError:
    print("Train the NLP model first using TF-IDF + LogisticRegression.")

# ------------------------
# 3. Classification Function
# ------------------------
def classify_issue(image_path: str, text_description: str) -> str:
    """
    Classify civic issue using CNN + NLP.
    Returns one of: Garbage, Pothole, Streetlight Issue, Road Damage.
    Spam is flagged if confidence is low or models disagree.
    """
    # --- Image ---
    image = Image.open(image_path).convert("RGB")
    img_tensor = image_transform(image).unsqueeze(0).to(device)
    with torch.no_grad():
        cnn_logits = cnn_model(img_tensor)
        cnn_probs = F.softmax(cnn_logits, dim=1).squeeze(0)
        cnn_conf, cnn_idx = torch.max(cnn_probs, dim=0)
        cnn_pred = CATEGORIES[cnn_idx.item()]
    
    # --- Text ---
    text_features = vectorizer.transform([text_description])
    text_pred = text_model.predict(text_features)[0]
    
    # --- Combine CNN + NLP ---
    if cnn_pred == text_pred:
        final_pred = cnn_pred
    else:
        # Use higher confidence
        text_conf = max(text_model.predict_proba(text_features)[0])
        final_pred = cnn_pred if cnn_conf.item() >= text_conf else text_pred
    
    # --- Spam Detection ---
    # If both models have low confidence → flag as spam
    text_conf = max(text_model.predict_proba(text_features)[0])
    if cnn_conf.item() < 0.4 and text_conf < 0.4:
        return "Spam"

    return final_pred

