from django.core.management.base import BaseCommand

from complaints.models import Complaint


class Command(BaseCommand):
    help = "Recompute priority scores for all complaints using the priority engine."

    def handle(self, *args, **options):
        updated = 0
        for c in Complaint.objects.all():
            c.recompute_priority()
            c.save(update_fields=["priority_score", "priority_label", "updated_at"])
            updated += 1

        self.stdout.write(self.style.SUCCESS(f"Recomputed priority for {updated} complaints."))

