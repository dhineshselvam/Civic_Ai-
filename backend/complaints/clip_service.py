"""
CLIP-based issue classification.
Uses locally installed openai/clip-vit-base-patch32 (do NOT download).
"""
import os
from pathlib import Path

# Categories for civic issues
CATEGORIES = [
    "Garbage",
    "Pothole",
    "Streetlight Issue",
    "Road Damage",
]

# Default local path; override via env CLIP_MODEL_PATH (set to actual path if model is elsewhere)
_env_path = os.environ.get("CLIP_MODEL_PATH", "").strip()
DEFAULT_LOCAL_MODEL_PATH = _env_path or os.path.join(
    os.path.dirname(__file__), "..", "..", "clip_model",
)


def _get_model_path():
    """Resolve local CLIP model path (already installed)."""
    path = Path(DEFAULT_LOCAL_MODEL_PATH)
    if path.exists():
        return str(path.resolve())
    # Fallback: Hugging Face cache hub/models--openai--clip-vit-base-patch32/snapshots/<id>
    hf_home = os.environ.get("HF_HOME", os.path.expanduser("~/.cache/huggingface"))
    hub_path = Path(hf_home) / "hub"
    if hub_path.exists():
        for d in hub_path.iterdir():
            if d.is_dir() and "clip" in d.name.lower() and "vit" in d.name.lower():
                snapshots = d / "snapshots"
                if snapshots.exists():
                    for s in snapshots.iterdir():
                        if s.is_dir():
                            return str(s)
                return str(d)
    return DEFAULT_LOCAL_MODEL_PATH


def classify_issue(image_path: str, text_description: str) -> str:
    """
    Classify a civic issue from image path and text description using local CLIP.
    Returns one of: Garbage, Pothole, Water Leakage, Streetlight Issue, Road Damage.
    """
    model_path = _get_model_path()
    if not os.path.exists(model_path):
        raise FileNotFoundError(
            f"CLIP model not found at {model_path}. "
            "Set CLIP_MODEL_PATH to the local openai/clip-vit-base-patch32 path."
        )

    try:
        from transformers import CLIPModel, CLIPProcessor
        from PIL import Image
        import torch
    except ImportError as e:
        raise ImportError(
            "Install transformers, torch, and Pillow: "
            "pip install transformers torch pillow"
        ) from e

    device = "cuda" if torch.cuda.is_available() else "cpu"
    model = CLIPModel.from_pretrained(model_path, local_files_only=True)
    processor = CLIPProcessor.from_pretrained(model_path, local_files_only=True)
    model = model.to(device)
    model.eval()

    image = Image.open(image_path).convert("RGB")
    inputs = processor(
        text=CATEGORIES,
        images=image,
        return_tensors="pt",
        padding=True,
        truncation=True,
    )
    inputs = {k: v.to(device) for k, v in inputs.items()}

    with torch.no_grad():
        outputs = model(**inputs)
        logits_per_image = outputs.logits_per_image
        probs = logits_per_image.softmax(dim=1).squeeze(0)

    idx = probs.argmax().item()
    return CATEGORIES[idx]
