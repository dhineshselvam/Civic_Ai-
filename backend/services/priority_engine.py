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
    sensitive_location_count: int = 0


BASE_PRIORITY_SCORE = 35


def _base_from_category(category: str) -> int:
    """Return the neutral base priority score."""
    return BASE_PRIORITY_SCORE


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
    return min(matches * 5, 15)


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
        return 10   # Highly Trusted: bigger bump to ensure their claims jump the queue
    if trust_score >= 50:
        return 5    # Trusted: slight bump
    if trust_score >= 30:
        return 0    # Normal: no impact
    if trust_score >= 15:
        return -10  # Low Trust: penalty for historical inaccuracies
    return -20      # Unreliable: severe penalty for spammers


def _sensitive_location_bonus(count: int) -> int:
    """
    Sensitive Location Bonus (+10 per location, max +30)

    If the reported issue occurs within 500 metres of schools, hospitals,
    or universities, the system increases the priority score (+10 each) to ensure
    faster response in areas where public safety is more critical.
    The bonus is capped at +30.
    """
    if not count or count < 0:
        return 0
    return min(count * 10, 30)


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
    sensitive_location_count: int = 0,
) -> Tuple[int, str]:
    """
    Priority Engine – single public entry point.

    Combines 7 factors:
    1. Category base score   (Neutral base score of 35)
    2. Description danger keywords (+15–30)
    3. Night-time bonus (+5 between 8 pm–5 am)
    4. Duplicate / upvote bonus (+3 per extra upvote)
    5. Age bonus (+2 per unresolved day, capped at +30)
    6. Credibility bonus from reporter trust score buckets (-20 to +15)
    7. Sensitive Location Bonus (+10 per detected location within 500m, max +30)

    Final score is clamped to [0, 100].
    """
    base = _base_from_category(category)
    score = base

    score += _danger_bonus(description)
    score += _night_bonus(timestamp)
    score += _upvote_bonus(upvote_count)
    score += _age_bonus(timestamp, is_resolved)
    score += _credibility_bonus(trust_score)
    score += _sensitive_location_bonus(sensitive_location_count)

    score = max(0, min(int(score), 100))
    label = _label_from_score(score)
    return score, label

