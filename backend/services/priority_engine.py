from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Optional, Tuple


@dataclass
class PriorityContext:
    """Inputs used by the priority engine."""

    category: str
    description: str
    timestamp: datetime
    is_resolved: bool
    upvote_count: int = 1
    trust_score: Optional[int] = None


def _base_from_category(category: str) -> int:
    """Map fine-grained category text into Road / Garbage / Streetlight buckets."""
    text = (category or "").lower()

    # Road damage ecosystem
    if any(k in text for k in ["pothole", "road", "street", "pavement", "bridge"]):
        return 40  # Road

    # Waste / sanitation
    if any(k in text for k in ["garbage", "waste", "trash", "bin", "dump", "sewage", "drain"]):
        return 25  # Garbage

    # Lighting / electrical
    if any(k in text for k in ["light", "lamp", "streetlight", "bulb", "electric", "power"]):
        return 20  # Streetlight

    # Everything else – neutral but still visible in queue
    return 20


def _danger_bonus(description: str) -> int:
    text = (description or "").lower()
    
    # Severity keywords focused exclusively on Road, Garbage, and Streetlight issues
    danger_keywords = [
        # Road / Pothole Severity
        "accident", "crash", "injury", "injured", "fall", "fell", 
        "flat tire", "broken axle", "crater", "deep", "hazard", 
        "severe", "damaged vehicle", "flipped", "dangerous", "urgent",
        
        # Garbage / Sanitation Severity
        "biohazard", "toxic", "disease", "dead animal", "rats", 
        "maggots", "infested", "needles", "sharp glass", "medical waste", 
        "foul smell", "unbearable stench", "blocking the road",
        
        # Streetlight / Electrical Severity
        "pitch dark", "completely black", "unsafe", "blind spot", 
        "sparking", "exposed wire", "live wire", "hanging wire", 
        "electrocute", "electrocution", "short circuit", "burning smell"
    ]
    
    matches = sum(1 for kw in danger_keywords if kw in text)
    if matches == 0:
        return 0
    # Base +15 for any match, +5 for each additional match (cap at +30)
    return min(15 + (matches - 1) * 5, 30)


def _night_bonus(ts: datetime) -> int:
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    hour = ts.hour
    # Night-time window ~8pm–5am with +5 bonus
    return 5 if (hour >= 20 or hour < 5) else 0


def _upvote_bonus(upvote_count: int) -> int:
    # Every additional citizen confirming the same issue is +3
    if upvote_count is None:
        upvote_count = 1
    extra = max(0, upvote_count - 1)
    return extra * 3


def _age_bonus(ts: datetime, is_resolved: bool) -> int:
    if is_resolved:
        return 0
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    now = datetime.now(timezone.utc)
    days_open = max(0, int((now - ts).total_seconds() // 86400))
    # +2 per day open, capped to avoid runaway scores
    return min(days_open * 2, 30)


def _credibility_bonus(trust_score: Optional[int]) -> int:
    if trust_score is None:
        return 0
    # Adjusted severity scaling for credibility impact
    if trust_score >= 80:
        return 15   # Highly Trusted: bigger bump to ensure their claims jump the queue
    if trust_score >= 50:
        return 5    # Trusted: slight bump
    if trust_score >= 30:
        return 0    # Normal: no impact
    if trust_score >= 15:
        return -10  # Low Trust: penalty for historical inaccuracies
    return -20      # Unreliable: severe penalty for spammers


def _label_from_score(score: int) -> str:
    if score >= 80:
        return "Critical"
    if score >= 60:
        return "High"
    if score >= 40:
        return "Medium"
    return "Low"


def calculate_priority_score(
    *,
    category: str,
    description: str,
    timestamp: datetime,
    is_resolved: bool,
    upvote_count: int = 1,
    trust_score: Optional[int] = None,
) -> Tuple[int, str]:
    """
    Priority Engine – single public entry point.

    Combines:
    - Category base (Road/Garbage/Streetlight → 40/25/20)
    - Description danger keywords
    - Night-time bonus
    - Duplicate upvote bonus (+3 per upvote beyond the first)
    - Age bonus (+2 per unresolved day, capped)
    - Credibility bonus from trust score buckets
    """
    base = _base_from_category(category)
    score = base

    score += _danger_bonus(description)
    score += _night_bonus(timestamp)
    score += _upvote_bonus(upvote_count)
    score += _age_bonus(timestamp, is_resolved)
    score += _credibility_bonus(trust_score)

    score = max(0, min(int(score), 100))
    label = _label_from_score(score)
    return score, label

