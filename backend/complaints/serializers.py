from rest_framework import serializers

from .models import Complaint


class ComplaintCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating complaints (multipart form)."""

    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    timestamp = serializers.DateTimeField()

    class Meta:
        model = Complaint
        fields = [
            'image',
            'description',
            'latitude',
            'longitude',
            'timestamp',
            'predicted_category',
        ]
        read_only_fields = ['predicted_category']


class ComplaintResponseSerializer(serializers.Serializer):
    """Response shape for POST /api/report-issue/."""

    message = serializers.CharField()
    predicted_category = serializers.CharField()
