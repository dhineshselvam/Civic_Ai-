from django.db import models
from django.utils import timezone

from services.priority_engine import calculate_priority_score


class Complaint(models.Model):
    """Civic issue report with image, location, and AI-predicted category."""

    STATUS_CHOICES = [
        ('Reported', 'Reported'),
        ('Verified', 'Verified'),
        ('Assigned', 'Assigned'),
        ('In-Progress', 'In-Progress'),
        ('Resolved', 'Resolved'),
    ]

    PRIORITY_CHOICES = [
        ('Low', 'Low'),
        ('Medium', 'Medium'),
        ('High', 'High'),
        ('Critical', 'Critical'),
    ]

    image = models.ImageField(upload_to='complaints/')
    description = models.TextField()
    latitude = models.FloatField()
    longitude = models.FloatField()
    timestamp = models.DateTimeField()
    predicted_category = models.CharField(max_length=255)
    address = models.CharField(max_length=500, null=True, blank=True)
    priority_score = models.IntegerField(default=50)        # 0-100
    priority_label = models.CharField(max_length=20, choices=PRIORITY_CHOICES, default='Medium')
    upvote_count = models.IntegerField(default=1)
    image_hash = models.CharField(max_length=64, null=True, blank=True)
    
    # Task 1.2 Additions
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Reported')
    user = models.ForeignKey('users.CustomUser', on_delete=models.SET_NULL, null=True, blank=True, related_name='complaints')
    assigned_teams = models.ManyToManyField('users.Team', blank=True, related_name='assigned_tasks')
    assigned_users = models.ManyToManyField('users.CustomUser', blank=True, related_name='assigned_individual_tasks')
    
    rating = models.IntegerField(null=True, blank=True)
    feedback = models.TextField(null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-priority_score', '-created_at']

    def __str__(self):
        return f"[{self.priority_label}] {self.predicted_category} @ ({self.latitude}, {self.longitude})"

    def recompute_priority(self):
        """
        Re-run the priority engine for this complaint using the latest
        category, description, timestamps, upvotes, and reporter credibility.
        """
        user = self.user
        trust = user.trust_score if user is not None else None
        # Use original complaint timestamp for age + night-time logic
        ts = self.timestamp or timezone.now()
        score, label = calculate_priority_score(
            category=self.predicted_category or "",
            description=self.description or "",
            timestamp=ts,
            is_resolved=self.status == 'Resolved',
            upvote_count=self.upvote_count or 1,
            trust_score=trust,
        )
        self.priority_score = score
        self.priority_label = label

    def save(self, *args, **kwargs):
        is_new = self.pk is None
        old_status = None
        if not is_new:
            old_instance = Complaint.objects.get(pk=self.pk)
            old_status = old_instance.status
        else:
            # Fresh complaints get their initial priority from the engine
            self.recompute_priority()

        super().save(*args, **kwargs)

        if is_new and self.user:
            self.user.reports_count += 1
            self.user.save()

        # When an issue is resolved, boost citizen trust score
        if self.user and old_status != 'Resolved' and self.status == 'Resolved':
            self.user.resolved_count += 1
            self.user.trust_score = min(100, self.user.trust_score + 5)
            self.user.save()
