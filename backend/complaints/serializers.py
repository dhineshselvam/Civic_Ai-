from rest_framework import serializers

from .models import Complaint, UserReport


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
            'created_at', 'updated_at', 'department', 'genuinity_status', 'sla_deadline'
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

class UserReportSerializer(serializers.ModelSerializer):
    """
    Serializer for the UserReport layer.
    Exposes the same shape as ComplaintSerializer so the frontend doesn't break,
    but draws core issue details from the parent Complaint.
    """
    image_url = serializers.SerializerMethodField()
    complaint_id = serializers.IntegerField(source='complaint.id', read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)
    predicted_category = serializers.CharField(source='complaint.predicted_category', read_only=True)
    priority_score = serializers.IntegerField(source='complaint.priority_score', read_only=True)
    priority_label = serializers.CharField(source='complaint.priority_label', read_only=True)
    status = serializers.CharField(source='complaint.status', read_only=True)
    upvote_count = serializers.IntegerField(source='complaint.upvote_count', read_only=True)
    assigned_teams = serializers.SerializerMethodField()
    assigned_users = serializers.SerializerMethodField()
    rating = serializers.IntegerField(source='complaint.rating', read_only=True)
    feedback = serializers.CharField(source='complaint.feedback', read_only=True)
    genuinity_status = serializers.CharField(source='complaint.genuinity_status', read_only=True)
    sla_deadline = serializers.DateTimeField(source='complaint.sla_deadline', read_only=True)

    class Meta:
        model = UserReport
        # Expose the same fields as ComplaintSerializer for seamless frontend integration
        fields = [
            'id', 'complaint_id', 'image', 'image_url', 'description', 'latitude', 'longitude', 'timestamp',
            'predicted_category', 'priority_score', 'priority_label', 'address', 'upvote_count',
            'status', 'assigned_teams', 'assigned_users', 'rating', 'feedback',
            'created_at', 'is_original', 'username', 'genuinity_status', 'sla_deadline'
        ]

    def get_image_url(self, obj):
        request = self.context.get('request')
        if obj.image and request:
            return request.build_absolute_uri(obj.image.url)
        return None

    def get_assigned_users(self, obj):
        from users.serializers import UserSerializer
        return UserSerializer(obj.complaint.assigned_users.all(), many=True).data

    def get_assigned_teams(self, obj):
        teams_data = []
        for team in obj.complaint.assigned_teams.prefetch_related('members').all():
            teams_data.append({
                'id': team.id,
                'name': team.name,
                'department': team.department,
                'members': [m.username for m in team.members.all()]
            })
        return teams_data


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
    genuinity_status = serializers.CharField()
