"""
demo_complaints.py  (v4 - bulk_create bypasses ALL save() hooks & signals)
===========================================================================
SLA + Notification Demo Script for Civic AI.

Run from backend/:
    python manage.py shell -c "exec(open('scripts/demo_complaints.py', encoding='utf-8').read())"

What changed in v4:
  - Uses Complaint.objects.bulk_create() which completely bypasses:
      * Django pre_save / post_save signals
      * The custom Complaint.save() method (priority engine, CLIP, OSM, etc.)
  - Immediately after bulk_create, uses queryset.update() to force-set:
      * created_at    -> backdated value (bypasses auto_now_add)
      * sla_deadline  -> calculated from backdated created_at
      * response_deadline -> calculated from backdated created_at
      * All notification flags -> False (ensures run_sla_check fires fresh)
  - Links every complaint to the first ADMIN user (guarantees notifications)
  - Calls run_sla_check() which generates Notification rows the UI shows.
"""

import os, shutil
from datetime import timedelta
from django.utils import timezone

# ── Constants — mirror models.py / sla_service.py ────────────────────────────
SLA_HOURS      = {"Critical": 3,  "High": 8,  "Medium": 24, "Low": 72}
RESPONSE_HOURS = {"Critical": 1,  "High": 4,  "Medium": 12, "Low": 36}
PRIORITY_SCORE = {"Critical": 90, "High": 70, "Medium": 50, "Low": 25}

BASE_DIR   = os.getcwd()                         # must be run from backend/
IMG_BASE   = os.path.join(BASE_DIR, "image_demo")

SRC_IMAGES = {
    "garbage":     os.path.join(IMG_BASE, "garbage",     "Garbage_bin_00013.jpg"),
    "road":        os.path.join(IMG_BASE, "road",        "15.jpg"),
    "streetlight": os.path.join(IMG_BASE, "streetlight", "13.jpg"),
}

# ── Case design ───────────────────────────────────────────────────────────────
# age_hours = how old the complaint is (how far back created_at is set)
# This controls which SLA event fires:
#   A) normal:            age < response hours            → nothing triggered
#   B) response_warning:  age > resp_hours, < sla_hours  → response notification
#   C) resolution_warning:inside escalation window        → escalation alert
#   D) breach:            age > sla_hours                 → SLA breach notification

DEMO_CASES = [
    {
        "label":       "A – Normal (no SLA event yet)",
        "img_key":     "garbage",
        "priority":    "High",            # SLA=8h, Resp=4h
        "category":    "Garbage Dumping",
        "department":  "SANITATION",
        "description": "Garbage overflow near residential area. Bins overflowing and causing health hazard.",
        "status":      "Reported",
        "case_type":   "normal",
        "age_hours":   0.05,              # 3 min old  → both deadlines in future
    },
    {
        "label":       "B – Response Warning",
        "img_key":     "garbage",
        "priority":    "High",            # SLA=8h, Resp=4h
        "category":    "Garbage Dumping",
        "department":  "SANITATION",
        "description": "Uncollected garbage bins blocking street entrance. Foul smell spreading to adjacent streets.",
        "status":      "Reported",
        "case_type":   "response_warning",
        "age_hours":   4.5,               # 4.5h old → resp_dl passed (4h ago+30m), sla_dl still 3.5h away
    },
    {
        "label":       "C – Resolution Warning (inside escalation window)",
        "img_key":     "streetlight",
        "priority":    "Medium",          # SLA=24h, Resp=12h, escalation_window=240min=4h
        "category":    "Streetlight Issue",
        "department":  "ELECTRICITY",
        "description": "Streetlight not working at night near school zone causing safety risk for pedestrians.",
        "status":      "Verified",
        "case_type":   "resolution_warning",
        "age_hours":   21.0,              # 21h old → sla_dl is 3h away (inside 4h escalation window)
    },
    {
        "label":       "D – SLA Breach",
        "img_key":     "road",
        "priority":    "Critical",        # SLA=3h, Resp=1h
        "category":    "Pothole",
        "department":  "PWD",
        "description": "Major pothole on main road near Jawaharlal Nehru Street causing vehicle damage.",
        "status":      "Reported",
        "case_type":   "breach",
        "age_hours":   3.5,               # 3.5h old → sla_dl was 3h → 30min PAST = BREACH
    },
]

# ── Helpers ────────────────────────────────────────────────────────────────────

def get_admin_user():
    from users.models import CustomUser
    user = CustomUser.objects.filter(role="ADMIN").first() \
        or CustomUser.objects.filter(is_superuser=True).first()
    if not user:
        user = CustomUser.objects.create_user(
            username="demo_admin", email="demo@civicai.local",
            password="demo1234", role="ADMIN",
        )
        print(f"  Created demo admin: {user.username}")
    return user


def copy_image(img_key):
    """Copy demo image into media/complaints/ and return its DB-relative path."""
    src = SRC_IMAGES[img_key]
    if not os.path.isfile(src):
        raise FileNotFoundError(f"Image not found: {src}")
    dst_dir = os.path.join(BASE_DIR, "media", "complaints")
    os.makedirs(dst_dir, exist_ok=True)
    fname = f"demo_{img_key}_{os.path.basename(src)}"
    dst = os.path.join(dst_dir, fname)
    if not os.path.exists(dst):
        shutil.copy2(src, dst)
    return f"complaints/{fname}"


# ── Main ──────────────────────────────────────────────────────────────────────

def run():
    from complaints.models import Complaint
    from services.sla_service import run_sla_check
    from users.models import Notification

    now  = timezone.now()
    user = get_admin_user()

    print("\n" + "=" * 65)
    print("  CIVIC AI — SLA DEMO COMPLAINT GENERATOR  (v4)")
    print(f"  Admin user : {user.username}  (id={user.id})")
    print(f"  Time now   : {now.strftime('%Y-%m-%d %H:%M:%S %Z')}")
    print("=" * 65)

    created_ids   = []
    complaint_objs = []

    for case in DEMO_CASES:
        priority   = case["priority"]
        age_h      = case["age_hours"]
        created_at = now - timedelta(hours=age_h)
        sla_dl     = created_at + timedelta(hours=SLA_HOURS[priority])
        resp_dl    = created_at + timedelta(hours=RESPONSE_HOURS[priority])
        img_path   = copy_image(case["img_key"])

        # Build object without saving — bulk_create skips save() and signals
        obj = Complaint(
            user               = user,
            image              = img_path,
            description        = case["description"],
            latitude           = 11.9416,
            longitude          = 79.8083,
            timestamp          = created_at,       # complaint timestamp
            predicted_category = case["category"],
            address            = "Puducherry, Tamil Nadu",
            priority_label     = priority,
            priority_score     = PRIORITY_SCORE[priority],
            department         = case["department"],
            status             = case["status"],
            genuinity_status   = "Verified",
            upvote_count       = 1,
            # SLA fields – will be overwritten by update() below anyway
            sla_deadline       = sla_dl,
            response_deadline  = resp_dl,
            # Flags all False so run_sla_check() fires fresh notifications
            sla_breach_notified  = False,
            response_notified    = False,
            resolution_notified  = False,
        )
        complaint_objs.append((obj, case, created_at, sla_dl, resp_dl))

    # ── bulk_create: inserts ALL rows WITHOUT calling save() or signals ───────
    raw_objs = [x[0] for x in complaint_objs]
    inserted = Complaint.objects.bulk_create(raw_objs)

    # ── Immediately fix created_at + deadlines per complaint ─────────────────
    #    (bulk_create sets created_at=now via auto_now_add; we override it)
    for ins_obj, (_, case, created_at, sla_dl, resp_dl) in zip(inserted, complaint_objs):
        Complaint.objects.filter(pk=ins_obj.pk).update(
            created_at          = created_at,
            sla_deadline        = sla_dl,
            response_deadline   = resp_dl,
            sla_breach_notified = False,
            response_notified   = False,
            resolution_notified = False,
        )
        ins_obj.refresh_from_db()
        created_ids.append(ins_obj.pk)

        over_resp = now > ins_obj.response_deadline
        over_sla  = now > ins_obj.sla_deadline

        print(f"\n  {case['label']}")
        print(f"    ID          : #{ins_obj.pk}")
        print(f"    Priority    : {case['priority']}")
        print(f"    Created at  : {ins_obj.created_at.strftime('%Y-%m-%d %H:%M %Z')}")
        print(f"    Response DL : {ins_obj.response_deadline.strftime('%Y-%m-%d %H:%M %Z')}"
              f"  <- {'PASSED ✓' if over_resp else 'future'}")
        print(f"    SLA DL      : {ins_obj.sla_deadline.strftime('%Y-%m-%d %H:%M %Z')}"
              f"  <- {'PASSED ✓' if over_sla else 'future'}")
        print(f"    user_id     : {ins_obj.user_id}")
        print(f"    Expected    : [{case['case_type'].upper()}]")

    # ── Run SLA check — writes Notification rows ─────────────────────────────
    print(f"\n{'=' * 65}")
    print("  Running run_sla_check() → writing notification rows ...")
    print("=" * 65)

    result = run_sla_check()

    print(f"\n  SLA check results:")
    for k, v in result.items():
        print(f"    {k:<34}: {v}")

    # ── Show notifications generated ──────────────────────────────────────────
    print(f"\n{'=' * 65}")
    print(f"  NOTIFICATIONS generated for '{user.username}':")
    print("=" * 65)

    notifs = Notification.objects.filter(
        user=user,
        complaint_id__in=created_ids        # only from THIS run
    ).order_by("-created_at") if hasattr(Notification, 'complaint_id') else \
    Notification.objects.filter(user=user).order_by("-created_at")[:12]

    # Fallback: just show last 12
    all_notifs = list(Notification.objects.filter(user=user).order_by("-created_at")[:12])
    if not all_notifs:
        print("  ⚠  No notifications found. Check sla_deadline values above.")
    for n in all_notifs:
        icon = {"breach": "🔴", "response_warning": "🟠",
                "resolution_warning": "🟡", "general": "⚪"}.get(n.type, "⚫")
        print(f"  {icon} [{n.type:<22}] {n.title}")

    # ── Final summary ─────────────────────────────────────────────────────────
    print(f"\n{'=' * 65}")
    print("  SUMMARY")
    print("=" * 65)
    print(f"  Complaints created     : {len(created_ids)}  → IDs {created_ids}")
    print(f"  Breach notified        : {result.get('breach_notified', 0)}")
    print(f"  Response notified      : {result.get('response_phase_notified', 0)}")
    print(f"  Escalated              : {result.get('escalated', 0)}")
    print(f"\n  → Login to Flutter app as: {user.username}")
    print(f"  → Open Notifications / Alerts tab to see the type badges.\n")

run()
