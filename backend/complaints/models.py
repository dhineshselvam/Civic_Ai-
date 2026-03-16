from django.db import models
from django.utils import timezone

from services.priority_engine import calculate_priority_score
from services.sensitive_location_detection import detect_sensitive_location


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

    DEPARTMENT_CHOICES = [
        ('PWD', 'PWD – Roads & Infrastructure'),
        ('SANITATION', 'Sanitation'),
        ('ELECTRICITY', 'Electricity'),
        ('GENERAL', 'General'),
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
    department = models.CharField(max_length=20, choices=DEPARTMENT_CHOICES, default='GENERAL')
    
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
        category, description, timestamps, upvotes, reporter credibility,
        and the detected sensitive-location count.
        """
        if self.predicted_category == "Spam":
            self.priority_score = 0
            self.priority_label = 'Low'
            return

        user = self.user
        trust = user.trust_score if user is not None else None
        # Use original complaint timestamp for age + night-time logic
        ts = self.timestamp or timezone.now()
        
        # Get sensitive_location_count
        sensitive_count = getattr(self, '_temp_sensitive_count', None)
        if sensitive_count is None:
            if self.pk:
                first_loc = self.sensitive_locations.first()
                sensitive_count = first_loc.count if first_loc else 0
            else:
                sensitive_count = 0

        score, label = calculate_priority_score(
            category=self.predicted_category or "",
            description=self.description or "",
            timestamp=ts,
            is_resolved=self.status == 'Resolved',
            upvote_count=self.upvote_count or 1,
            trust_score=trust,
            sensitive_location_count=sensitive_count,
        )
        self.priority_score = score
        self.priority_label = label

    def _assign_department(self):
        """Auto-set department based on predicted_category text."""
        text = (self.predicted_category or '').lower()
        if any(k in text for k in ['pothole', 'road', 'pavement', 'bridge', 'infrastructure']):
            self.department = 'PWD'
        elif any(k in text for k in ['garbage', 'waste', 'trash', 'bin', 'dump', 'sewage', 'drain', 'sanitation']):
            self.department = 'SANITATION'
        elif any(k in text for k in ['streetlight', 'light', 'lamp', 'electric', 'power', 'pole', 'bulb']):
            self.department = 'ELECTRICITY'
        else:
            self.department = 'GENERAL'

    def save(self, *args, **kwargs):
        is_new = self.pk is None
        old_status = None
        if not is_new:
            old_instance = Complaint.objects.get(pk=self.pk)
            old_status = old_instance.status
        else:
            # Detect sensitive location ONCE at creation (OSM lookup — may be slow)
            try:
                loc_count, loc_names = detect_sensitive_location(
                    self.latitude,
                    self.longitude,
                )
            except Exception:
                loc_count, loc_names = 0, "error"
                
            self._temp_sensitive_count = loc_count
            self._temp_sensitive_names = loc_names

            if self.predicted_category == "Spam":
                self.priority_score = 0
                self.priority_label = 'Low'
                self.department = 'GENERAL'
            else:
                # Fresh complaints get their initial priority from the engine
                # (recompute_priority now reads _temp_sensitive_count)
                self.recompute_priority()
                # Auto-route to department based on predicted_category
                self._assign_department()

        super().save(*args, **kwargs)

        if is_new:
            loc_count = getattr(self, '_temp_sensitive_count', 0)
            loc_names = getattr(self, '_temp_sensitive_names', None)
            
            SensitiveLocation.objects.create(
                complaint=self,
                count=loc_count,
                name_sensitive_location=loc_names
            )

            if self.user:
                self.user.reports_count += 1
                self.user.save()

        # When an issue is resolved, boost citizen trust score
        if self.user and old_status != 'Resolved' and self.status == 'Resolved':
            self.user.resolved_count += 1
            self.user.trust_score = min(100, self.user.trust_score + 5)
            self.user.save()


class SensitiveLocation(models.Model):
    """Stores the list of detected sensitive locations for a complaint."""
    complaint = models.ForeignKey(Complaint, on_delete=models.CASCADE, related_name='sensitive_locations')
    count = models.IntegerField(help_text="Total number of detected sensitive places")
    name_sensitive_location = models.JSONField(help_text="List of names, 'error', or null", null=True, blank=True)

    def __str__(self):
        return f"Locations: {self.name_sensitive_location} (Count: {self.count}) - Complaint #{self.complaint_id}"


class UserReport(models.Model):
    """An individual submission by a citizen. Links to a master Complaint."""
    
    complaint = models.ForeignKey(Complaint, on_delete=models.CASCADE, related_name='user_reports')
    user = models.ForeignKey('users.CustomUser', on_delete=models.SET_NULL, null=True, blank=True, related_name='individual_reports')
    
    image = models.ImageField(upload_to='complaints/')
    description = models.TextField()
    latitude = models.FloatField()
    longitude = models.FloatField()
    timestamp = models.DateTimeField()
    address = models.CharField(max_length=500, null=True, blank=True)
    
    is_original = models.BooleanField(default=False, help_text="True if this was the first report that created the Complaint")
    
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Report by {self.user.username if self.user else 'Anonymous'} for Complaint #{self.complaint.id}"
