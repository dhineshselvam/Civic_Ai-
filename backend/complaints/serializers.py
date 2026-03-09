from rest_framework import serializers

from .models import Complaint


class ComplaintSerializer(serializers.ModelSerializer):
    """Full serializer for viewing complaint details."""
    image_url = serializers.SerializerMethodField()
    assigned_teams = serializers.SerializerMethodField()
    assigned_users = serializers.SerializerMethodField()

    class Meta:
        model = Complaint
        fields = [
            'id', 'image', 'image_url', 'description', 'latitude', 'longitude', 'timestamp',
            'predicted_category', 'priority_score', 'priority_label', 'address', 'upvote_count',
            'status', 'assigned_teams', 'assigned_users', 'rating', 'feedback',
            'created_at', 'updated_at'
        ]

    def get_assigned_users(self, obj):
        from users.serializers import UserSerializer
        return UserSerializer(obj.assigned_users.all(), many=True).data

    def get_assigned_teams(self, obj):
        teams_data = []
        for team in obj.assigned_teams.prefetch_related('members').all():
            teams_data.append({
                'id': team.id,
                'name': team.name,
                'department': team.department,
                'members': [m.username for m in team.members.all()]
            })
        return teams_data

    def get_image_url(self, obj):
        request = self.context.get('request')
        if obj.image and request:
            return request.build_absolute_uri(obj.image.url)
        return None


class ComplaintCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating complaints (multipart form)."""

    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    timestamp = serializers.DateTimeField()

    class Meta:
        model = Complaint
        fields = [
            'id',
            'image',
            'description',
            'latitude',
            'longitude',
            'timestamp',
            'predicted_category',
            'status',
            'priority_score',
            'priority_label',
        ]
        read_only_fields = ['id', 'predicted_category', 'status', 'priority_score', 'priority_label']


class ComplaintFeedbackSerializer(serializers.ModelSerializer):
    """Serializer for users to provide rating and feedback."""
    class Meta:
        model = Complaint
        fields = ['rating', 'feedback']
        extra_kwargs = {
            'rating': {'required': True},
            'feedback': {'required': False},
        }


class ComplaintResponseSerializer(serializers.Serializer):
    """Response shape for POST /api/report-issue/."""

    message = serializers.CharField()
    predicted_category = serializers.CharField()
    complaint_id = serializers.IntegerField()
    priority_score = serializers.IntegerField()
    priority_label = serializers.CharField()
