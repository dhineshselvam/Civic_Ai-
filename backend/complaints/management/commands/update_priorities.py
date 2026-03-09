from django.core.management.base import BaseCommand
from complaints.models import Complaint

class Command(BaseCommand):
    help = 'Recomputes priority scores for all unresolved complaints.'

    def handle(self, *args, **options):
        # Fetch complaints that are not yet resolved
        unresolved_complaints = Complaint.objects.exclude(status='Resolved')
        
        updated_count = 0
        for complaint in unresolved_complaints:
            old_score = complaint.priority_score
            complaint.recompute_priority()
            # Save only if score changed to avoid unnecessary DB writes
            if old_score != complaint.priority_score:
                # use update_fields to only save the priority fields to be efficient
                # but wait, upvote_count and others might change? No, only score/label changes
                complaint.save(update_fields=['priority_score', 'priority_label'])
                updated_count += 1

        self.stdout.write(self.style.SUCCESS(f'Successfully recomputed priorities. Updated {updated_count} complaints.'))
