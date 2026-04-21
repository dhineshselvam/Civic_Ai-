from django.contrib.auth.models import AbstractUser
from django.db import models

class Team(models.Model):
    """
    Crew members are assigned to Teams for deployment.
    """
    DEPARTMENT_CHOICES = (
        ('ROAD', 'Road Maintenance'),
        ('SANITATION', 'Sanitation & Waste'),
        ('ELECTRICAL', 'Electrical & Lighting'),
        ('WATER', 'Water & Drainage'),
        ('PARKS', 'Parks & Public Spaces'),
        ('GENERAL', 'General Maintenance'),
    )
    name = models.CharField(max_length=50, unique=True)
    department = models.CharField(max_length=20, choices=DEPARTMENT_CHOICES, null=True, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} ({self.department})"

class CustomUser(AbstractUser):
    """
    Custom user model for Civic AI.
    Uses email for OTP-based authentication and role-based dashboards.
    """
    ROLE_CHOICES = (
        ('CITIZEN', 'Citizen'),
        ('CREW', 'Field Crew'),
        ('ADMIN', 'System Admin'),
        ('PWD', 'PWD Department'),
        ('SANITATION', 'Sanitation Department'),
        ('ELECTRICITY', 'Electricity Department'),
    )

    email = models.EmailField(unique=True)
    phone_number = models.CharField(max_length=15, null=True, blank=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='CITIZEN')
    department = models.CharField(max_length=20, choices=Team.DEPARTMENT_CHOICES, null=True, blank=True)
    team = models.ForeignKey(Team, on_delete=models.SET_NULL, null=True, blank=True, related_name='members')
    trust_score = models.IntegerField(default=50)  # Neutral score to start
    
    # Track contributions
    reports_count = models.IntegerField(default=0)
    resolved_count = models.IntegerField(default=0)
    
    USERNAME_FIELD = 'username'
    REQUIRED_FIELDS = ['email']

    def __str__(self):
        return self.email

    @property
    def credibility_label(self) -> str:
        """
        Bucket trust_score into human-readable credibility labels.

        Used in the UI and also conceptually inside the priority engine
        (which consumes the numeric trust_score for scoring bonuses).
        """
        score = self.trust_score or 0
        if score >= 80:
            return "Trusted"
        if score >= 40:
            return "Normal"
        if score >= 20:
            return "Low"
        return "Unreliable"

class ActivityLog(models.Model):
    """Records actions performed by Admin/Department users for the profile Activity Summary."""
    user = models.ForeignKey(
        'CustomUser',
        on_delete=models.CASCADE,
        related_name='activity_logs',
    )
    role = models.CharField(max_length=20, blank=True)
    action = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-timestamp']

    def __str__(self):
        return f"[{self.role}] {self.user.username}: {self.action[:60]}"


def log_activity(user, action: str) -> None:
    """Convenience helper — create an ActivityLog entry if user is a staff role."""
    staff_roles = ('ADMIN', 'PWD', 'SANITATION', 'ELECTRICITY', 'CREW')
    if user and getattr(user, 'role', None) in staff_roles:
        ActivityLog.objects.create(user=user, role=user.role, action=action)


class PasswordResetToken(models.Model):
    """Secure token for email-based password reset."""
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)
    token = models.CharField(max_length=100, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_used = models.BooleanField(default=False)

class Notification(models.Model):
    """Truly free in-app notification store."""
    NOTIFICATION_TYPE_CHOICES = [
        ('general', 'General'),
        ('response_warning', 'Response Warning'),
        ('resolution_warning', 'Resolution Warning'),
        ('breach', 'Breach'),
    ]
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='notifications')
    title = models.CharField(max_length=255)
    message = models.TextField()
    type = models.CharField(
        max_length=30,
        choices=NOTIFICATION_TYPE_CHOICES,
        default='general',
        help_text="Category of notification for UI badge display"
    )
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Notification for {self.user.email}: {self.title}"
