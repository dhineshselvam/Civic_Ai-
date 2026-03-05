import os
from datetime import timedelta

import django
import pandas as pd

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
django.setup()

from django.utils import timezone
from complaints.models import Complaint


def build_timeseries():
  """
  Aggregate complaints by day and coarse grid cell (lat, lon bucket).
  Returns a dataframe with columns: ds (date), y (count), lat_bin, lon_bin.
  """
  qs = Complaint.objects.all().values("latitude", "longitude", "created_at")
  if not qs:
    return pd.DataFrame(columns=["ds", "y", "lat_bin", "lon_bin"])

  df = pd.DataFrame.from_records(qs)
  df["ds"] = df["created_at"].dt.date

  # Bucket locations into a simple grid (~0.01 deg ≈ city block scale)
  df["lat_bin"] = df["latitude"].round(2)
  df["lon_bin"] = df["longitude"].round(2)

  grouped = (
    df.groupby(["lat_bin", "lon_bin", "ds"])
    .size()
    .reset_index(name="y")
    .sort_values("ds")
  )
  return grouped


def forecast_next_30_days(ts_df):
  """
  For each grid cell, fit a Prophet model on daily counts and
  forecast the next 30 days. Returns a dataframe with columns:
  lat_bin, lon_bin, ds, yhat (forecasted count).
  """
  try:
    from prophet import Prophet
  except ImportError:
    try:
      from fbprophet import Prophet  # older package name
    except ImportError:
      print("Prophet is not installed; cannot run forecasting.")
      return pd.DataFrame(columns=["lat_bin", "lon_bin", "ds", "yhat"])

  results = []
  horizon = 30

  for (lat_bin, lon_bin), cell_df in ts_df.groupby(["lat_bin", "lon_bin"]):
    # Prophet expects columns ds (datetime) and y (numeric)
    cell = cell_df[["ds", "y"]].copy()
    cell["ds"] = pd.to_datetime(cell["ds"])

    if len(cell) < 3:
      # Not enough history; approximate by recent mean
      recent_mean = cell["y"].tail(7).mean() if len(cell) else 0.0
      future_dates = pd.date_range(
        start=timezone.now().date() + timedelta(days=1),
        periods=horizon,
        freq="D",
      )
      for d in future_dates:
        results.append(
          {
            "lat_bin": lat_bin,
            "lon_bin": lon_bin,
            "ds": d,
            "yhat": recent_mean,
          }
        )
      continue

    try:
      m = Prophet(daily_seasonality=True, weekly_seasonality=True)
      m.fit(cell)
      future = m.make_future_dataframe(periods=horizon, freq="D")
      forecast = m.predict(future)
      # Keep only the forecast horizon
      future_part = forecast.tail(horizon)[["ds", "yhat"]]
      for _, row in future_part.iterrows():
        results.append(
          {
            "lat_bin": lat_bin,
            "lon_bin": lon_bin,
            "ds": row["ds"].date(),
            "yhat": float(row["yhat"]),
          }
        )
    except Exception as exc:
      print(f"Prophet failed for cell ({lat_bin}, {lon_bin}): {exc}")

  return pd.DataFrame(results)


def generate_heatmap(output_path: str | None = None):
  """
  Full pipeline:
  - Read complaint history
  - Aggregate per grid cell and day
  - Use Prophet to forecast next 30 days of complaints per cell
  - Aggregate forecasts into a single intensity score per cell
  - Render a static heatmap PNG for the Flutter admin dashboard
  """
  import matplotlib.pyplot as plt
  from matplotlib.colors import LinearSegmentedColormap

  ts_df = build_timeseries()
  if ts_df.empty:
    print("No complaints yet; nothing to forecast.")
    return

  forecast_df = forecast_next_30_days(ts_df)
  if forecast_df.empty:
    print("No forecast data produced (Prophet missing?).")
    return

  # Sum forecasted counts across the 30‑day horizon per grid cell
  agg = (
    forecast_df.groupby(["lat_bin", "lon_bin"])["yhat"]
    .sum()
    .reset_index()
  )

  # Build scatter heatmap from grid centroids
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
    agg["lon_bin"],
    agg["lat_bin"],
    c=agg["yhat"],
    cmap=cmap,
    alpha=0.85,
    s=60,
  )
  plt.colorbar(label="Forecasted complaints over next 30 days")
  plt.title("Predictive Civic Issue Hotspots – 30‑day Forecast")
  plt.xlabel("Longitude")
  plt.ylabel("Latitude")
  plt.tight_layout()

  if output_path is None:
    base_dir = os.path.dirname(
      os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    )
    output_path = os.path.join(
      base_dir, "frontend", "web", "assets", "hotspots.png"
    )
    output_path = os.path.normpath(output_path)

  os.makedirs(os.path.dirname(output_path), exist_ok=True)
  plt.savefig(output_path, dpi=160)
  plt.close()
  print(f"Forecast heatmap written to: {output_path}")


if __name__ == "__main__":
  generate_heatmap()

