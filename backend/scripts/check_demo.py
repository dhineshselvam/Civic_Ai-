import sys
from users.models import Notification, CustomUser
from complaints.models import Complaint
from django.db.models import Count
from django.utils import timezone

now = timezone.now()
u = CustomUser.objects.filter(role='ADMIN').first()
print(f"Admin user: {u.username} (id={u.id})")

print("\n--- Notification counts by type ---")
counts = Notification.objects.filter(user=u).values('type').annotate(c=Count('id'))
for r in counts:
    print(f"  {r['type']:<25}: {r['c']}")
print(f"  {'TOTAL':<25}: {Notification.objects.filter(user=u).count()}")

print("\n--- Last 4 demo complaints ---")
for c in Complaint.objects.order_by('-id')[:4]:
    over_resp = c.response_deadline and now > c.response_deadline
    over_sla  = c.sla_deadline and now > c.sla_deadline
    tag = 'BREACH' if over_sla else ('RESP_WARN' if over_resp else 'NORMAL')
    print(f"  #{c.id} {c.priority_label:<9} user={c.user_id}"
          f" resp_ok={c.response_notified}"
          f" sla_ok={c.sla_breach_notified}"
          f"  [{tag}]")
    rdl = c.response_deadline.strftime('%H:%M') if c.response_deadline else 'None'
    sdl = c.sla_deadline.strftime('%H:%M') if c.sla_deadline else 'None'
    cat = c.created_at.strftime('%H:%M') if c.created_at else 'None'
    print(f"    resp_dl={rdl}  sla_dl={sdl}  created={cat}")

print("\n--- Last 8 notifications (type + title stripped of emoji) ---")
for n in Notification.objects.filter(user=u).order_by('-id')[:8]:
    safe_title = n.title.encode('ascii', 'replace').decode('ascii')
    print(f"  [{n.type:<22}] {safe_title}")

print("\n--- DONE ---")
