"""
Sensitive Location Detection Service
=====================================
Queries the OpenStreetMap Overpass API to detect whether a given
lat/lon is within 500 metres of a **school**, **hospital**, **university**, or **college**.

This module is intentionally kept as a pure I/O service so that the
Priority Engine (priority_engine.py) remains a side-effect-free
calculation module.

Public API
----------
    detect_sensitive_location(latitude, longitude) -> tuple[int, list[str] | str | None]
        Returns:
        - (count, list_of_names) if ≥1 school, hospital, etc. found.
        - (0, None) if the API succeeds but finds NO locations.
        - (0, "error") if the API call fails or times out.
"""

from __future__ import annotations

import logging
from typing import Optional, Tuple, List, Union

import requests

logger = logging.getLogger(__name__)

# ── Configuration ──────────────────────────────────────────────────────────────

_OVERPASS_URL = "https://overpass-api.de/api/interpreter"
_RADIUS_METRES = 500
_TIMEOUT_SECONDS = 6  # hard cap — never block complaint creation

# ── Overpass query template ────────────────────────────────────────────────────

_QUERY_TEMPLATE = """
[out:json];
(
  node(around:{radius},{lat},{lon})["amenity"="school"];
  node(around:{radius},{lat},{lon})["amenity"="hospital"];
  node(around:{radius},{lat},{lon})["amenity"="university"];
  node(around:{radius},{lat},{lon})["amenity"="college"];
  way(around:{radius},{lat},{lon})["amenity"="school"];
  way(around:{radius},{lat},{lon})["amenity"="hospital"];
  way(around:{radius},{lat},{lon})["amenity"="university"];
  way(around:{radius},{lat},{lon})["amenity"="college"];
);
out tags;
"""


# ── Public function ────────────────────────────────────────────────────────────

def detect_sensitive_location(
    latitude: float,
    longitude: float,
    *,
    radius: int = _RADIUS_METRES,
    timeout: int = _TIMEOUT_SECONDS,
) -> Tuple[int, Optional[Union[List[str], str]]]:
    """
    Return count and names if a school, hospital, university, or college exists within *radius* metres.

    Failures (network error, timeout, unexpected response) are caught
    and logged; the function then returns (0, "error") to indicate failure explicitly.
    is never blocked.

    Parameters
    ----------
    latitude, longitude : float
        WGS-84 coordinates of the reported issue.
    radius : int
        Search radius in metres (default 500).
    timeout : int
        HTTP request timeout in seconds (default 3).

    Returns
    -------
    tuple[int, list[str] | str | None]
        - Success (>0 locs) -> (count, ["name1", "name2"])
        - Success (0 locs)  -> (0, None)
        - Failure           -> (0, "error")
    """
    try:
        query = _QUERY_TEMPLATE.format(
            radius=radius,
            lat=round(latitude, 6),
            lon=round(longitude, 6),
        )
        response = requests.post(
            _OVERPASS_URL,
            data={"data": query},
            timeout=timeout,
        )
        response.raise_for_status()
        data = response.json()

        elements = data.get("elements", [])

        names = []
        for element in elements:
            name = element.get("tags", {}).get("name")
            if name and name not in names:
                names.append(name)
                print(f"[Sensitive Location] {name}")

        count = len(names)
        if count > 0:
            return count, names
        
        return 0, None

    except requests.Timeout as exc:
        logger.error(
            "sensitive_location_detection: Overpass API timed out for (%.5f, %.5f): %s. "
            "Returning 'error'.",
            latitude,
            longitude,
            exc,
        )
        return 0, "error"
    except requests.RequestException as exc:
        logger.error(
            "sensitive_location_detection: Network error for (%.5f, %.5f): %s. "
            "Returning 'error'.",
            latitude,
            longitude,
            exc,
        )
        return 0, "error"
    except (ValueError, KeyError, IndexError) as exc:
        logger.error(
            "sensitive_location_detection: Unexpected response for (%.5f, %.5f): %s. "
            "Returning 'error'.",
            latitude,
            longitude,
            exc,
        )
        return 0, "error"
    except Exception as exc:
        logger.error(
            "sensitive_location_detection: Unknown error for (%.5f, %.5f): %s. "
            "Returning 'error'.",
            latitude,
            longitude,
            exc,
        )
        return 0, "error"
