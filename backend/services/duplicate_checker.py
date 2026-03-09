from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, List, Tuple

from django.db.models import Q

from complaints.models import Complaint

try:
    from PIL import Image
    import imagehash
except ImportError:  # pragma: no cover - handled at runtime
    Image = None
    imagehash = None

try:
    from sklearn.cluster import DBSCAN
except ImportError:  # pragma: no cover - handled at runtime
    DBSCAN = None


@dataclass
class DuplicateMatch:
    """Result of a duplicate lookup."""

    complaint: Complaint
    distance: int


def compute_image_hash(image_path: str) -> Optional[str]:
    """
    Compute a perceptual hash (phash) for the given image path.
    Returns hex string or None if hashing library is unavailable.
    """
    if Image is None or imagehash is None:
        return None
    with Image.open(image_path) as img:
        ph = imagehash.phash(img)
    return str(ph)


def find_nearby_duplicate(
    *,
    latitude: float,
    longitude: float,
    image_hash_hex: str,
    max_distance: int = 8,
    radius_deg: float = 0.002,
) -> Optional[DuplicateMatch]:
    """
    Look for an unresolved complaint near the given coordinates whose
    perceptual hash is within `max_distance` Hamming distance, and that
    also falls into the same GPS cluster as the new report (DBSCAN).
    """
    if not image_hash_hex:
        return None

    # Quick geo bounding-box filter (~200m radius, depends on latitude)
    lat_min = latitude - radius_deg
    lat_max = latitude + radius_deg
    lon_min = longitude - radius_deg
    lon_max = longitude + radius_deg

    candidates = Complaint.objects.filter(
        status__in=['Reported', 'Verified', 'Assigned', 'In-Progress'],
        latitude__gte=lat_min,
        latitude__lte=lat_max,
        longitude__gte=lon_min,
        longitude__lte=lon_max,
    ).exclude(Q(image_hash__isnull=True) | Q(image_hash__exact=""))

    if not candidates.exists():
        return None

    # Build coordinate list for DBSCAN: all candidates + the new point
    candidate_coords: List[Tuple[float, float]] = [
        (c.latitude, c.longitude) for c in candidates
    ]
    new_coord = (latitude, longitude)
    all_coords = candidate_coords + [new_coord]

    # Default: consider all candidates in bounding box if DBSCAN unavailable
    cluster_indices = set(range(len(candidate_coords)))

    if DBSCAN is not None:
        try:
            # eps in degrees (~0.001 ≈ 100m); min_samples=1 to always cluster lone points
            clustering = DBSCAN(eps=0.001, min_samples=1).fit(all_coords)
            labels = clustering.labels_
            new_label = labels[-1]
            # Only consider candidates in the same GPS cluster as the new point
            cluster_indices = {
                idx for idx, label in enumerate(labels[:-1]) if label == new_label
            }
        except Exception:
            # Fallback to simple bounding box if clustering fails
            cluster_indices = set(range(len(candidate_coords)))

    best: Optional[DuplicateMatch] = None
    try:
        new_hash = imagehash.hex_to_hash(image_hash_hex)
    except Exception:
        return None

    for idx, c in enumerate(candidates):
        if idx not in cluster_indices:
            continue
        try:
            existing_hash = imagehash.hex_to_hash(c.image_hash)
        except Exception:
            continue
        dist = new_hash - existing_hash  # Hamming distance
        if dist <= max_distance:
            if best is None or dist < best.distance:
                best = DuplicateMatch(complaint=c, distance=dist)

    return best

