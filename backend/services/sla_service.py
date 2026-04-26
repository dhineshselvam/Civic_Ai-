"""
services/sla_service.py
=======================
Ideal SLA monitoring, escalation, alerting, and breach-logging service.

Design rules
------------
  1.  sla_deadline is set ONCE at complaint creation and NEVER reset.
  2.  Escalation happens BEFORE the deadline, inside tier-specific trigger windows.
  3.  Breach is recorded ONLY after the deadline; no further escalation occurs then.
  4.  last_escalated_at guards against repeated escalations within the same window.

Priority tiers and deadlines
-----------------------------
  Critical → 3 hours
  High     → 8 hours
  Medium   → 24 hours
  Low      → 72 hours  (backward-compatible with the old 3-day rule)

Escalation trigger windows (minutes before deadline)
------------------------------------------------------
  Low      → escalate 720 min (12 h) before deadline
  Medium   → escalate 240 min (4 h)  before deadline
  High     → escalate 120 min (2 h)  before deadline
  Critical → escalate  30 min        before deadline

Public API
----------
  get_sla_deadline(complaint)         → datetime | None
  get_time_remaining(complaint)       → timedelta | None
  is_sla_breached(complaint)          → bool
  is_near_deadline(complaint, buffer) → bool
  escalate_priority_tier(complaint)   → bool  (True if escalated)
  run_sla_check()                     → dict  (summary stats)
  mock_sms_alert(complaint, reason)   → None
"""

from __future__ import annotations

import logging
from datetime import timedelta
from typing import Optional

from django.utils import timezone

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# SLA_HOURS must mirror _SLA_TIER_HOURS in complaints/models.py
SLA_HOURS: dict[str, int] = {
    "Critical": 0.1,
    "High": 0.2,
    "Medium": 0.3,
    "Low": 0.4,
}

# Response-phase hours: must mirror _RESPONSE_HOURS in complaints/models.py
RESPONSE_HOURS: dict[str, int] = {
    "Critical": 0.05,
    "High": 0.1,
    "Medium": 0.15,
    "Low": 0.2,
}

# Per-tier window (minutes before deadline) at which we trigger escalation.
# The complaint must still be unresolved and unassigned at that moment.
ESCALATION_TRIGGER_MINUTES: dict[str, int] = {
    "Low":      720,   # 12 hours before deadline
    "Medium":   240,   # 4 hours before deadline
    "High":     120,   # 2 hours before deadline
    "Critical":  30,   # 30 minutes before deadline (already top tier — no escalation)
}

# Escalation chain: Low → Medium → High → Critical
_ESCALATION_CHAIN: list[str] = ["Low", "Medium", "High", "Critical"]

# Statuses considered "active" for SLA purposes
_ACTIVE_STATUSES = ["Reported", "Verified"]

# Default "approaching" buffer used by dashboard stats (backward compat)
DEFAULT_NEAR_DEADLINE_BUFFER_MINUTES = 60


# ---------------------------------------------------------------------------
# Low-level utilities (pure / no DB)
# ---------------------------------------------------------------------------

def get_sla_deadline(complaint) -> Optional[object]:
    """
    Return the SLA deadline for *complaint*.

    Prefers the stored ``sla_deadline`` (immutable after creation).
    Falls back to a dynamic calculation for legacy rows without the field,
    so the function always returns a usable value.
    """
    if complaint.sla_deadline:
        return complaint.sla_deadline

    base = complaint.created_at
    if base is None:
        return None
    hours = SLA_HOURS.get(complaint.priority_label, 72)
    return base + timedelta(hours=hours)


def get_time_remaining(complaint) -> Optional[timedelta]:
    """
    Return time remaining before the SLA deadline.
    Returns a *negative* timedelta if the deadline has already passed.
    Returns None if the deadline cannot be determined.
    """
    deadline = get_sla_deadline(complaint)
    if deadline is None:
        return None
    return deadline - timezone.now()


def is_sla_breached(complaint) -> bool:
    """True if the complaint is active AND its SLA deadline has passed."""
    if complaint.status not in _ACTIVE_STATUSES:
        return False
    remaining = get_time_remaining(complaint)
    if remaining is None:
        return False
    return remaining.total_seconds() < 0


def is_near_deadline(
    complaint,
    buffer_minutes: int = DEFAULT_NEAR_DEADLINE_BUFFER_MINUTES,
) -> bool:
    """
    True if the complaint is active and will breach within *buffer_minutes*.
    Used by dashboard stats — buffer defaults to 60 min for backward compat.
    """
    if complaint.status not in _ACTIVE_STATUSES:
        return False
    remaining = get_time_remaining(complaint)
    if remaining is None:
        return False
    return 0 <= remaining.total_seconds() <= buffer_minutes * 60


def escalate_priority_tier(complaint) -> bool:
    """
    Bump *complaint* one tier (Low→Medium→High→Critical).

    Key rule: does NOT touch sla_deadline — the original deadline is permanent.

    Updates in-place (no .save() call — caller must bulk_update):
      - priority_label
      - priority_score  (raised to tier floor if needed)
      - last_escalated_at

    Returns True if escalated, False if already Critical.
    """
    current = complaint.priority_label or "Low"
    try:
        idx = _ESCALATION_CHAIN.index(current)
    except ValueError:
        idx = 0

    if idx >= len(_ESCALATION_CHAIN) - 1:
        return False  # Already at Critical — cannot escalate further

    new_tier = _ESCALATION_CHAIN[idx + 1]
    complaint.priority_label = new_tier

    # Raise priority_score to the new tier's floor (never lower it)
    tier_score_floors = {"Low": 20, "Medium": 45, "High": 65, "Critical": 85}
    complaint.priority_score = max(
        complaint.priority_score,
        tier_score_floors[new_tier],
    )

    # Record when this escalation happened (prevents duplicate upgrades)
    complaint.last_escalated_at = timezone.now()

    # sla_deadline is intentionally NOT modified here
    return True


# ---------------------------------------------------------------------------
# Alerting helpers
# ---------------------------------------------------------------------------

def _send_email_alert(complaint, subject: str, body: str) -> None:
    """Send alert email to the complaint reporter; logs failures silently."""
    try:
        from django.core.mail import send_mail
        from django.conf import settings

        if not (complaint.user and complaint.user.email):
            return

        send_mail(
            subject=subject,
            message=body,
            from_email=getattr(settings, "DEFAULT_FROM_EMAIL", "noreply@civicai.com"),
            recipient_list=[complaint.user.email],
            fail_silently=True,
        )
        logger.info(
            "SLA alert email sent to %s for complaint #%s",
            complaint.user.email,
            complaint.pk,
        )
    except Exception as exc:  # pylint: disable=broad-except
        logger.error("SLA email alert failed for complaint #%s: %s", complaint.pk, exc)


def mock_sms_alert(complaint, reason: str) -> None:
    """
    SMS stub — prints to console.
    Replace with a real Twilio / SMS SDK call in production.
    """
    phone = getattr(complaint.user, "phone_number", None) if complaint.user else None
    logger.info(
        "[SMS MOCK] To=%s Complaint=#%s Reason=%s",
        phone or "N/A",
        complaint.pk,
        reason,
    )
    print(f"\n[SMS MOCK] Complaint #{complaint.pk} | {reason} | Phone: {phone or 'N/A'}\n")


def _send_in_app_notification(
    complaint, title: str, message: str, notification_type: str = "general"
) -> None:
    """
    Fan-out an SLA notification to all relevant staff.

    Recipients
    ----------
    - ADMIN users  : receive ALL SLA notifications (every complaint).
    - Dept users   : receive notifications ONLY for complaints whose
                     ``complaint.department`` matches their ``role``
                     (PWD, SANITATION, ELECTRICITY).
    - Citizens     : deliberately excluded — SLA alerts are operational,
                     not citizen-facing.
    """
    try:
        from complaints.notification_service import send_notification
        from users.models import CustomUser

        # 1. All admin users — always notified
        admin_users = list(
            CustomUser.objects.filter(role="ADMIN").only("id", "email", "role")
        )

        # 2. Department users scoped to this complaint's department
        department_users = []
        if complaint.department:
            department_users = list(
                CustomUser.objects.filter(role=complaint.department).only(
                    "id", "email", "role"
                )
            )

        # 3. Merge with deduplication (set on pk)
        seen_pks: set = set()
        recipients = []
        for user in admin_users + department_users:
            if user.pk not in seen_pks:
                seen_pks.add(user.pk)
                recipients.append(user)

        if not recipients:
            logger.warning(
                "SLA notification for complaint #%s has no recipients "
                "(no ADMIN or dept='%s' users found).",
                complaint.pk,
                complaint.department or "N/A",
            )
            return

        for user in recipients:
            send_notification(user, title, message, notification_type=notification_type)
            logger.info(
                "[SLA NOTIFY] complaint=#%s type=%s → %s (%s)",
                complaint.pk,
                notification_type,
                user.email,
                user.role,
            )

        logger.info(
            "SLA notification dispatched to %d recipient(s) for complaint #%s [%s]",
            len(recipients),
            complaint.pk,
            notification_type,
        )

    except Exception as exc:  # pylint: disable=broad-except
        logger.error(
            "SLA in-app notification FAILED for complaint #%s: %s",
            complaint.pk,
            exc,
            exc_info=True,
        )


# ---------------------------------------------------------------------------
# Main bulk runner
# ---------------------------------------------------------------------------

def run_sla_check() -> dict:
    """
    Core SLA monitoring loop. Called by the scheduler every 15 minutes.

    Algorithm (two mutually exclusive passes — no N+1 queries):

    PASS 1 — Breached (now > sla_deadline):
      • Do NOT escalate (deadline is already past — escalation is meaningless).
      • If not yet notified: log SLABreachLog, send breach alerts, mark notified.

    PASS 2 — Pre-deadline escalation (now <= sla_deadline):
      • For each active complaint compute:
            trigger_time = sla_deadline - ESCALATION_TRIGGER_MINUTES[priority_label]
      • If now >= trigger_time AND (last_escalated_at is None
                                    OR last_escalated_at < trigger_time):
            → escalate priority (does NOT change sla_deadline)
            → send warning alert
            → log SLABreachLog (reason: "Escalated X→Y – pre-deadline warning")

    Bulk DB writes at the end to minimise round-trips.
    """
    from complaints.models import Complaint, SLABreachLog  # avoid circular imports

    now = timezone.now()

    # Single queryset — select_related to avoid per-row user lookups
    active_qs = Complaint.objects.select_related("user").filter(
        status__in=_ACTIVE_STATUSES,
        sla_deadline__isnull=False,
    )

    # Split into the two mutually exclusive buckets
    breached_qs    = active_qs.filter(sla_deadline__lte=now)
    pre_breach_qs  = active_qs.filter(sla_deadline__gt=now)

    # Accumulators
    escalated_complaints:       list = []
    breach_notified_ids:        list = []
    response_notified_ids:      list = []   # NEW: response-phase tracker
    resolution_notified_ids:    list = []   # NEW: resolution-breach tracker
    log_entries:                list = []

    # ------------------------------------------------------------------
    # PASS 0 — Response Phase (new dual-layer logic)
    # Fire a warning notification when response_deadline has passed and
    # response_notified is still False.  No escalation, no sla_deadline changes.
    # ------------------------------------------------------------------
    response_overdue_qs = active_qs.filter(
        response_deadline__isnull=False,
        response_deadline__lte=now,
        response_notified=False,
    )
    for complaint in response_overdue_qs:
        _send_in_app_notification(
            complaint,
            "⚡ Response Deadline Passed",
            (
                f"Complaint #{complaint.pk} ({complaint.predicted_category}) has passed its "
                f"response deadline. Please ensure an initial response is recorded."
            ),
            notification_type="response_warning",
        )
        response_notified_ids.append(complaint.pk)
        logger.info("Response deadline passed for complaint #%s", complaint.pk)

    # ------------------------------------------------------------------
    # PASS 1 — Breach handling (existing logic, unchanged)
    # ------------------------------------------------------------------
    for complaint in breached_qs:
        if complaint.sla_breach_notified:
            continue  # already handled — skip to avoid duplicate logs/alerts

        reason = (
            f"SLA breached – unresolved after {SLA_HOURS.get(complaint.priority_label, 72)}h "
            f"({complaint.priority_label})"
        )
        log_entries.append(SLABreachLog(complaint=complaint, reason=reason))
        breach_notified_ids.append(complaint.pk)

        # Only send resolution_notified once (guards duplicate in-app breach alerts)
        if not complaint.resolution_notified:
            resolution_notified_ids.append(complaint.pk)

        # In-app breach notification
        _send_in_app_notification(
            complaint,
            "⚠️ SLA Breach",
            f"Complaint #{complaint.pk} ({complaint.predicted_category}) has breached its SLA.",
            notification_type="breach",
        )

        # Email alert
        _send_email_alert(
            complaint,
            subject=f"[CivicAI] SLA Breach – Issue #{complaint.pk}",
            body=(
                f"Dear {complaint.user.get_full_name() if complaint.user else 'Team'},\n\n"
                f"Issue #{complaint.pk} ({complaint.predicted_category}) at "
                f"{complaint.address or 'unknown location'} has breached its SLA.\n\n"
                f"Priority: {complaint.priority_label}\n"
                f"Status: {complaint.status}\n\n"
                f"Please take immediate action.\n\n– CivicAI System"
            ),
        )
        mock_sms_alert(complaint, reason)
        logger.warning("SLA breach confirmed for complaint #%s", complaint.pk)

    # ------------------------------------------------------------------
    # PASS 2 — Pre-deadline escalation
    # ------------------------------------------------------------------
    for complaint in pre_breach_qs:
        current_tier = complaint.priority_label or "Low"

        # Critical is already the maximum tier — no further escalation possible
        if current_tier == "Critical":
            continue

        trigger_minutes = ESCALATION_TRIGGER_MINUTES.get(current_tier, 720)
        trigger_time    = complaint.sla_deadline - timedelta(minutes=trigger_minutes)

        # Not yet inside the escalation window
        if now < trigger_time:
            continue

        # Guard: has already been escalated in this window?
        if complaint.last_escalated_at and complaint.last_escalated_at >= trigger_time:
            continue

        # Perform escalation (in-place, no save; caller does bulk_update)
        old_tier    = current_tier
        did_escalate = escalate_priority_tier(complaint)

        if not did_escalate:
            continue  # already Critical (shouldn't reach here, but be safe)

        new_tier = complaint.priority_label
        reason   = f"Escalated {old_tier}→{new_tier} (pre-deadline warning, {trigger_minutes} min window)"
        log_entries.append(SLABreachLog(complaint=complaint, reason=reason))
        escalated_complaints.append(complaint)

        # Escalation warning alert
        _send_in_app_notification(
            complaint,
            "⏰ SLA Escalation Warning",
            (
                f"Complaint #{complaint.pk} ({complaint.predicted_category}) has been escalated "
                f"from {old_tier} to {new_tier} priority. Please take action before the SLA deadline."
            ),
            notification_type="resolution_warning",
        )
        logger.info(
            "Escalated complaint #%s: %s→%s (trigger window: %d min)",
            complaint.pk, old_tier, new_tier, trigger_minutes,
        )

    # ------------------------------------------------------------------
    # Bulk DB writes — efficient, single round-trip per operation
    # ------------------------------------------------------------------
    if escalated_complaints:
        Complaint.objects.bulk_update(
            escalated_complaints,
            ["priority_label", "priority_score", "last_escalated_at"],
            # sla_deadline intentionally excluded — it never changes
        )

    if breach_notified_ids:
        Complaint.objects.filter(pk__in=breach_notified_ids).update(
            sla_breach_notified=True
        )

    if response_notified_ids:
        Complaint.objects.filter(pk__in=response_notified_ids).update(
            response_notified=True
        )

    if resolution_notified_ids:
        Complaint.objects.filter(pk__in=resolution_notified_ids).update(
            resolution_notified=True
        )

    if log_entries:
        SLABreachLog.objects.bulk_create(log_entries)

    # ------------------------------------------------------------------
    # Summary (dashboard-compatible keys)
    # ------------------------------------------------------------------
    near_threshold = now + timedelta(minutes=DEFAULT_NEAR_DEADLINE_BUFFER_MINUTES)
    near_deadline_count = active_qs.filter(
        sla_deadline__gt=now,
        sla_deadline__lte=near_threshold,
    ).count()

    summary = {
        "checked":                  active_qs.count(),
        "breached":                 breached_qs.count(),
        "breach_notified":          len(breach_notified_ids),
        "escalated":                len(escalated_complaints),
        "near_deadline":            near_deadline_count,
        "response_phase_notified":  len(response_notified_ids),   # NEW
        # Legacy key kept for backward compat with dashboard stats view
        "final_breach_logged": len(breach_notified_ids),
    }
    logger.info("SLA check complete: %s", summary)
    return summary


# ---------------------------------------------------------------------------
# Convenience query examples (for views / shell use)
# ---------------------------------------------------------------------------

def query_near_deadline(minutes: int = 60):
    """Return active complaints within *minutes* of their SLA deadline."""
    from complaints.models import Complaint
    now = timezone.now()
    threshold = now + timedelta(minutes=minutes)
    return Complaint.objects.filter(
        status__in=_ACTIVE_STATUSES,
        sla_deadline__isnull=False,
        sla_deadline__gt=now,
        sla_deadline__lte=threshold,
    ).select_related("user").order_by("sla_deadline")


def query_escalated():
    """Return active complaints that have been escalated at least once."""
    from complaints.models import Complaint
    return Complaint.objects.filter(
        status__in=_ACTIVE_STATUSES,
        last_escalated_at__isnull=False,
    ).select_related("user").order_by("-last_escalated_at")


def query_breached():
    """Return active complaints whose SLA deadline has passed."""
    from complaints.models import Complaint
    return Complaint.objects.filter(
        status__in=_ACTIVE_STATUSES,
        sla_deadline__isnull=False,
        sla_deadline__lte=timezone.now(),
    ).select_related("user").order_by("sla_deadline")
