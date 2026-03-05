import os
from transformers import CLIPModel, CLIPProcessor

def download_model():
    model_name = "openai/clip-vit-base-patch32"
    save_directory = os.path.join(os.path.dirname(__file__), "..", "clip_model")
    
    if not os.path.exists(save_directory):
        os.makedirs(save_directory)
    
    print(f"Downloading {model_name} to {save_directory}...")
    
    model = CLIPModel.from_pretrained(model_name)
    processor = CLIPProcessor.from_pretrained(model_name)
    
    model.save_pretrained(save_directory)
    processor.save_pretrained(save_directory)
    
    print("Model downloaded and saved successfully.")

if __name__ == "__main__":
    download_model()
