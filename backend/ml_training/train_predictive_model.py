"""
Train predictive models for Civic AI - Predictive Analysis module.

Models trained:
  1. RandomForestClassifier  → predicts complaint_type given (zone_enc, month, hour)
  2. Zone monthly stats      → compute per-zone × per-month average complaint counts
                               and risk thresholds (p33, p66) for dynamic risk leveling

Outputs (saved to ml_training/):
  - predictive_rf_model.pkl
  - zone_encoder.pkl
  - zone_risk_thresholds.pkl      (dict: zone → {'p33': v, 'p66': v, 'monthly_avg': {month: avg}})
  - zone_monthly_centroids.pkl    (dict: zone → {month → {'lat': v, 'lng': v}, 'fallback': {'lat': v, 'lng': v}})
  - zone_hotspots.pkl             (dict: zone → {month → {complaint_type → [{'lat': v, 'lng': v, 'weight': w}, ...]}})

Usage:
    cd backend
    python ml_training/train_predictive_model.py
"""

import os
import sys
import joblib
import pandas as pd
import numpy as np
from sklearn.cluster import KMeans
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, accuracy_score

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.join(BASE_DIR, '..', 'puducherry_civic_15k_final.csv')
OUT_DIR = BASE_DIR  # save alongside the script


def main():
    print("=" * 60)
    print("Civic AI – Predictive Model Training")
    print("=" * 60)

    # ------------------------------------------------------------------
    # 1. Load & parse dataset
    # ------------------------------------------------------------------
    print("\n[1/5] Loading dataset …")
    df = pd.read_csv(CSV_PATH)
    print(f"      Rows loaded: {len(df)}")

    if 'zone' not in df.columns and ' ' in df.columns:
        df = df.rename(columns={' ': 'zone'})

    # Clean text columns
    df['zone'] = df['zone'].str.strip().str.title()
    df['complaint_type'] = df['complaint_type'].str.strip().str.title()

    # Parse date and time columns safely
    df['date_parsed'] = pd.to_datetime(df['date'], errors='coerce')
    # If time contains ':', extract just the hour part first
    df['time_hour_only'] = df['time'].astype(str).str.split(':').str[0]
    df['hour'] = pd.to_numeric(df['time_hour_only'], errors='coerce')

    # Drop missing/invalid values safely
    before = len(df)
    df = df.dropna(subset=['date_parsed', 'hour', 'zone', 'complaint_type'])
    print(f"      Dropped rows: {before - len(df)}")

    # Ensure hour is int
    df['hour'] = df['hour'].astype(int)

    # Extract date features
    df['month'] = df['date_parsed'].dt.month
    df['day_of_week'] = df['date_parsed'].dt.dayofweek
    df['year'] = df['date_parsed'].dt.year

    print(f"      Valid rows after parsing: {len(df)}")
    print(f"      Zones: {sorted(df['zone'].unique())}")
    print(f"      Issue types: {sorted(df['complaint_type'].unique())}")

    if len(df) == 0:
        print("      ERROR: Dataset is empty after preprocessing. Check input paths/formats.")
        sys.exit(1)

    # ------------------------------------------------------------------
    # 2. Encode zone
    # ------------------------------------------------------------------
    print("\n[2/5] Encoding zone labels …")
    zone_encoder = LabelEncoder()
    df['zone_enc'] = zone_encoder.fit_transform(df['zone'])
    print(f"      Zone classes: {list(zone_encoder.classes_)}")

    # ------------------------------------------------------------------
    # 3. Compute zone × month risk thresholds + dynamic centroids
    # ------------------------------------------------------------------
    print("\n[3/5] Computing zone risk thresholds & monthly centroids …")

    # Group by zone + month, count total complaints per month
    monthly_counts = (
        df.groupby(['zone', 'month'])
        .size()
        .reset_index(name='count')
    )

    # Compute per-zone × per-month mean lat/lng centroid
    monthly_centroids_df = (
        df.groupby(['zone', 'month'])[['latitude', 'longitude']]
        .mean()
        .reset_index()
    )

    # Overall fallback centroid per zone (all months combined)
    fallback_centroids_df = (
        df.groupby('zone')[['latitude', 'longitude']]
        .mean()
    )

    zone_risk_thresholds = {}
    zone_monthly_centroids = {}

    for zone in df['zone'].unique():
        zone_data = monthly_counts[monthly_counts['zone'] == zone]
        all_counts = zone_data['count'].values
        if len(all_counts) == 0:
            p33, p66 = 0.0, 0.0
        else:
            p33 = float(np.percentile(all_counts, 33))
            p66 = float(np.percentile(all_counts, 66))

        # Per-month total dict
        monthly_dict = dict(zip(zone_data['month'].astype(int), zone_data['count']))
        zone_risk_thresholds[zone] = {
            'p33': p33,
            'p66': p66,
            'monthly_avg': monthly_dict,
        }
        print(f"      {zone}: p33={p33:.2f}, p66={p66:.2f}")

        # Build monthly centroid lookup for this zone
        zone_cent_rows = monthly_centroids_df[monthly_centroids_df['zone'] == zone]
        monthly_cent = {}
        for _, row in zone_cent_rows.iterrows():
            monthly_cent[int(row['month'])] = {
                'lat': round(float(row['latitude']), 6),
                'lng': round(float(row['longitude']), 6),
            }

        # Fallback: overall centroid for this zone
        if zone in fallback_centroids_df.index:
            fb_row = fallback_centroids_df.loc[zone]
            fallback = {
                'lat': round(float(fb_row['latitude']), 6),
                'lng': round(float(fb_row['longitude']), 6),
            }
        else:
            fallback = {'lat': 11.934, 'lng': 79.833}  # Puducherry default

        zone_monthly_centroids[zone] = {
            'monthly': monthly_cent,
            'fallback': fallback,
        }

    print(f"      Centroid months per zone: "
          f"{[len(v['monthly']) for v in zone_monthly_centroids.values()]}")

    # ------------------------------------------------------------------
    # 4. Compute exact hotspot clusters per zone × month × complaint_type
    # ------------------------------------------------------------------
    print("\n[4/6] Computing location hotspot clusters …")

    # How many hotspot pins to predict per zone+month+issue combo
    N_HOTSPOTS = 3

    # Structure: zone → month → complaint_type → list of {lat, lng, weight}
    zone_hotspots: dict = {}

    all_zones   = df['zone'].unique()
    all_months  = range(1, 13)
    all_issues  = df['complaint_type'].unique()

    for zone in all_zones:
        zone_hotspots[zone] = {}
        for month in all_months:
            zone_hotspots[zone][month] = {}
            for issue in all_issues:
                subset = df[
                    (df['zone'] == zone) &
                    (df['month'] == month) &
                    (df['complaint_type'] == issue)
                ][['latitude', 'longitude']].dropna()

                if len(subset) == 0:
                    # No historical data – skip (fallback handled in API)
                    continue

                n_clusters = min(N_HOTSPOTS, len(subset))

                if n_clusters == 1:
                    # Only one point – just use it directly
                    hotspots = [{
                        'lat':    round(float(subset['latitude'].iloc[0]),  6),
                        'lng':    round(float(subset['longitude'].iloc[0]), 6),
                        'weight': int(len(subset)),
                    }]
                else:
                    km = KMeans(
                        n_clusters=n_clusters,
                        random_state=42,
                        n_init='auto',
                    )
                    km.fit(subset[['latitude', 'longitude']].values)

                    # Weight each cluster by how many points it contains
                    labels  = km.labels_
                    centers = km.cluster_centers_
                    hotspots = []
                    for i, center in enumerate(centers):
                        cluster_size = int(np.sum(labels == i))
                        hotspots.append({
                            'lat':    round(float(center[0]), 6),
                            'lng':    round(float(center[1]), 6),
                            'weight': cluster_size,
                        })
                    # Sort by weight descending (most complaint-dense first)
                    hotspots.sort(key=lambda h: h['weight'], reverse=True)

                zone_hotspots[zone][month][issue] = hotspots

    total_hotspot_entries = sum(
        sum(len(issues) for issues in months.values())
        for months in zone_hotspots.values()
    )
    print(f"      Total hotspot entries computed: {total_hotspot_entries}")

    # ------------------------------------------------------------------
    # 5. Train RandomForest classifier
    # ------------------------------------------------------------------
    print("\n[5/6] Training RandomForest classifier …")

    FEATURES = ['zone_enc', 'month', 'hour', 'day_of_week']
    TARGET = 'complaint_type'

    X = df[FEATURES].values
    y = df[TARGET].values

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    rf = RandomForestClassifier(
        n_estimators=300,
        max_depth=None,
        min_samples_leaf=2,
        random_state=42,
        n_jobs=-1
    )
    rf.fit(X_train, y_train)

    y_pred = rf.predict(X_test)
    print(f"\n      Accuracy: {accuracy_score(y_test, y_pred):.4f}")
    print("\n      Classification Report:")
    print(classification_report(y_test, y_pred))

    # ------------------------------------------------------------------
    # 6. Save artefacts
    # ------------------------------------------------------------------
    print("[6/6] Saving model artefacts …")

    rf_path         = os.path.join(OUT_DIR, 'predictive_rf_model.pkl')
    enc_path        = os.path.join(OUT_DIR, 'zone_encoder.pkl')
    thresholds_path = os.path.join(OUT_DIR, 'zone_risk_thresholds.pkl')
    centroids_path  = os.path.join(OUT_DIR, 'zone_monthly_centroids.pkl')
    hotspots_path   = os.path.join(OUT_DIR, 'zone_hotspots.pkl')

    joblib.dump(rf, rf_path)
    joblib.dump(zone_encoder, enc_path)
    joblib.dump(zone_risk_thresholds, thresholds_path)
    joblib.dump(zone_monthly_centroids, centroids_path)
    joblib.dump(zone_hotspots, hotspots_path)

    print(f"      ✓ {rf_path}")
    print(f"      ✓ {enc_path}")
    print(f"      ✓ {thresholds_path}")
    print(f"      ✓ {centroids_path}")
    print(f"      ✓ {hotspots_path}")

    print("\n" + "=" * 60)
    print("SUCCESS – All models saved.")
    print("=" * 60)
    return 0


if __name__ == '__main__':
    sys.exit(main())
