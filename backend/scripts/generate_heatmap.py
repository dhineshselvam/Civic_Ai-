import os
from datetime import timedelta

import django
import pandas as pd

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
django.setup()

from django.utils import timezone
from complaints.models import Complaint


def build_dataframe():
    qs = Complaint.objects.all().values(
        "id", "latitude", "longitude", "predicted_category", "created_at"
    )
    if not qs:
        return pd.DataFrame(columns=["lat", "lon", "category", "date"])

    df = pd.DataFrame.from_records(qs)
    df["date"] = df["created_at"].dt.date
    df.rename(
        columns={
            "latitude": "lat",
            "longitude": "lon",
            "predicted_category": "category",
        },
        inplace=True,
    )
    return df[["lat", "lon", "category", "date"]]


def forecast_and_heatmap(output_path: str = None):
    """
    Generate a simple hotspot heatmap image using recent complaints.

    For review/demo this uses a lightweight approach:
    - Aggregates complaints by lat/lon grid and day
    - Uses a rolling 7‑day mean to approximate near‑term load
    - Renders a density heatmap to PNG via matplotlib
    """
    import matplotlib.pyplot as plt
    from matplotlib.colors import LinearSegmentedColormap

    df = build_dataframe()
    if df.empty:
        print("No complaints yet; nothing to plot.")
        return

    # Use only the last 60 days for "recent" city behaviour
    today = timezone.now().date()
    cutoff = today - timedelta(days=60)
    df = df[df["date"] >= cutoff]

    # Approximate forecast: rolling mean over the last 7 days per location
    df["count"] = 1
    daily = (
        df.groupby(["lat", "lon", "date"])["count"]
        .sum()
        .reset_index()
        .sort_values("date")
    )
    # 7‑day rolling window over time dimension
    daily["rolling"] = (
        daily.groupby(["lat", "lon"])["count"]
        .rolling(window=7, min_periods=1)
        .mean()
        .reset_index(level=[0, 1], drop=True)
    )

    # Prepare scatter heatmap
    plt.figure(figsize=(8, 6))
    cmap = LinearSegmentedColormap.from_list(
        "hotspots",
        [
            (0.0, "#0b1020"),
            (0.2, "#004b6b"),
            (0.5, "#00bcd4"),
            (0.8, "#ff9800"),
            (1.0, "#f44336"),
        ],
    )

    plt.scatter(
        daily["lon"],
        daily["lat"],
        c=daily["rolling"],
        cmap=cmap,
        alpha=0.8,
        s=40,
    )
    plt.colorbar(label="Forecasted complaint intensity (7‑day rolling mean)")
    plt.title("Predicted Civic Issue Hotspots (Next 30 days proxy)")
    plt.xlabel("Longitude")
    plt.ylabel("Latitude")
    plt.tight_layout()

    # Default output path inside frontend assets
    if output_path is None:
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        output_path = os.path.join(base_dir, "..", "frontend", "web", "assets", "hotspots.png")
        output_path = os.path.normpath(output_path)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    plt.savefig(output_path, dpi=160)
    plt.close()
    print(f"Hotspot heatmap written to: {output_path}")


if __name__ == "__main__":
    forecast_and_heatmap()

