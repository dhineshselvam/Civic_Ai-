from django.db import models


class Complaint(models.Model):
    """Civic issue report with image, location, and AI-predicted category."""

    image = models.ImageField(upload_to='complaints/')
    description = models.TextField()
    latitude = models.FloatField()
    longitude = models.FloatField()
    timestamp = models.DateTimeField()
    predicted_category = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.predicted_category} @ ({self.latitude}, {self.longitude})"
