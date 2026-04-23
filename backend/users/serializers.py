from rest_framework import serializers
from .models import CustomUser, Notification, Team, ActivityLog

class TeamSerializer(serializers.ModelSerializer):
    members = serializers.SerializerMethodField()

    class Meta:
        model = Team
        fields = ['id', 'name', 'department', 'is_active', 'created_at', 'members']

    def get_members(self, obj):
        return [
            {'id': m.id, 'username': m.username, 'is_supervisor': m.is_supervisor}
            for m in obj.members.all()
        ]

class ActivityLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = ActivityLog
        fields = ['id', 'action', 'role', 'timestamp']

class UserSerializer(serializers.ModelSerializer):
    credibility_label = serializers.CharField(read_only=True)
    team_name = serializers.SerializerMethodField()

    class Meta:
        model = CustomUser
        fields = [
            'id',
            'username',
            'email',
            'phone_number',
            'role',
            'department',
            'trust_score',
            'credibility_label',
            'reports_count',
            'resolved_count',
            'last_login',
            'team',
            'team_name',
            'is_supervisor',
            'current_latitude',
            'current_longitude',
            'city'
        ]
        read_only_fields = ['id', 'trust_score', 'credibility_label', 'reports_count', 'resolved_count', 'last_login']

    def get_team_name(self, obj):
        return obj.team.name if obj.team else None

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    # Phone is required for crew members
    phone_number = serializers.CharField(required=True)
    # Department optional for citizens
    department = serializers.ChoiceField(
        choices=[('ROAD', 'Road'), ('SANITATION', 'Sanitation'), ('ELECTRICAL', 'Electrical')],
        required=False,
        allow_null=True
    )
    # Email optional for crew
    email = serializers.EmailField(required=False, allow_blank=True)

    class Meta:
        model = CustomUser
        fields = ['username', 'email', 'phone_number', 'password', 'role', 'department', 'city']
        extra_kwargs = {
            'email': {'required': False, 'allow_blank': True},
            'phone_number': {'required': True},
        }

    def create(self, validated_data):
        # Email may be omitted for crew members; use None instead of empty string for uniqueness
        email = validated_data.get('email')
        if not email:
            email = None
            
        user = CustomUser.objects.create_user(
            username=validated_data['username'],
            email=email,
            password=validated_data['password'],
            phone_number=validated_data.get('phone_number', ''),
            role=validated_data.get('role', 'CITIZEN'),
            department=validated_data.get('department', None),
        )
        return user

class LoginSerializer(serializers.Serializer):
    username = serializers.CharField()
    password = serializers.CharField()

class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()

class PasswordResetConfirmSerializer(serializers.Serializer):
    email = serializers.EmailField()
    token = serializers.CharField()
    new_password = serializers.CharField()

class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'title', 'message', 'type', 'is_read', 'created_at']

