import secrets
import logging
from django.contrib.auth import authenticate
from django.core.mail import send_mail
from django.conf import settings
from rest_framework import status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from .models import CustomUser, PasswordResetToken, Notification, ActivityLog
from .serializers import (
    RegisterSerializer,
    LoginSerializer,
    UserSerializer,
    ActivityLogSerializer,
    NotificationSerializer,
    PasswordResetRequestSerializer,
    PasswordResetConfirmSerializer
)

logger = logging.getLogger(__name__)

class RegisterView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            refresh = RefreshToken.for_user(user)
            return Response({
                'refresh': str(refresh),
                'access': str(refresh.access_token),
                'user': UserSerializer(user).data
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class LoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        username = serializer.validated_data['username']
        password = serializer.validated_data['password']
        
        user = authenticate(request, username=username, password=password)
        if user:
            refresh = RefreshToken.for_user(user)
            return Response({
                'refresh': str(refresh),
                'access': str(refresh.access_token),
                'user': UserSerializer(user).data
            })
        return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)

class PasswordResetRequestView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        if serializer.is_valid():
            email = serializer.validated_data['email']
            try:
                user = CustomUser.objects.get(email=email)
                token = secrets.token_urlsafe(32)
                PasswordResetToken.objects.create(user=user, token=token)
                
                # Send email with reset token
                send_mail(
                    'Reset Your Civic Ai Password',
                    f'Your password reset token is: {token}',
                    settings.DEFAULT_FROM_EMAIL,
                    [email],
                    fail_silently=False,
                )
                return Response({'message': 'Reset token sent to email'})
            except CustomUser.DoesNotExist:
                return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class PasswordResetConfirmView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        if serializer.is_valid():
            email = serializer.validated_data['email']
            token = serializer.validated_data['token']
            new_password = serializer.validated_data['new_password']
            
            try:
                reset_token = PasswordResetToken.objects.get(user__email=email, token=token, is_used=False)
                user = reset_token.user
                user.set_password(new_password)
                user.save()
                reset_token.is_used = True
                reset_token.save()
                return Response({'message': 'Password reset successful'})
            except PasswordResetToken.DoesNotExist:
                return Response({'error': 'Invalid or expired token'}, status=status.HTTP_400_BAD_REQUEST)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class UserProfileView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        data = UserSerializer(request.user).data
        # For staff roles include activity summary
        staff_roles = ('ADMIN', 'PWD', 'SANITATION', 'ELECTRICITY', 'CREW')
        if request.user.role in staff_roles:
            logs = ActivityLog.objects.filter(user=request.user)[:10]
            data['recent_activity'] = ActivityLogSerializer(logs, many=True).data
        return Response(data)


class ActivityLogView(APIView):
    """GET /api/users/activity-log/ — last 10 ActivityLog entries for the requesting user."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        logs = ActivityLog.objects.filter(user=request.user)[:10]
        return Response(ActivityLogSerializer(logs, many=True).data)

class NotificationListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        notifications = request.user.notifications.all()[:50]
        serializer = NotificationSerializer(notifications, many=True)
        return Response(serializer.data)

    def post(self, request):
        request.user.notifications.filter(is_read=False).update(is_read=True)
        return Response({'message': 'All notifications marked as read'})


class NotificationDetailView(APIView):
    """POST /api/users/notifications/<id>/read/ — mark a single notification as read."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            notification = request.user.notifications.get(pk=pk)
            notification.is_read = True
            notification.save(update_fields=['is_read'])
            return Response({'message': 'Notification marked as read'})
        except Notification.DoesNotExist:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

class CrewRegistrationView(APIView):
    """Register field crew members. Admins can register any; dept admins register for their dept."""
    permission_classes = [permissions.IsAuthenticated]

    DASHBOARD_ROLES = ('ADMIN', 'PWD', 'SANITATION', 'ELECTRICITY', 'CREW')

    def post(self, request):
        if request.user.role not in self.DASHBOARD_ROLES:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        
        from .serializers import RegisterSerializer, UserSerializer
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            # Force role to CREW
            user = serializer.save()
            user.role = 'CREW'
            
            # Dept isolation: force department to match registrar's dept if not super admin
            if request.user.role != 'ADMIN':
                role_to_dept = {'PWD': 'ROAD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICAL'}
                user.department = role_to_dept.get(request.user.role)
            
            user.save()
            return Response(UserSerializer(user).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class TeamListView(APIView):
    """List and create teams. Admins see all; dept admins see their own."""
    permission_classes = [permissions.IsAuthenticated]

    DASHBOARD_ROLES = ('ADMIN', 'PWD', 'SANITATION', 'ELECTRICITY', 'CREW')

    def get(self, request):
        if request.user.role not in self.DASHBOARD_ROLES:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        
        from .models import Team
        from .serializers import TeamSerializer
        
        role_to_dept = {'PWD': 'ROAD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICAL'}
        
        if request.user.role == 'ADMIN':
            teams = Team.objects.all()
        else:
            dept = role_to_dept.get(request.user.role)
            teams = Team.objects.filter(department=dept)
            
        serializer = TeamSerializer(teams, many=True)
        return Response(serializer.data)

    def post(self, request):
        if request.user.role not in self.DASHBOARD_ROLES:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
            
        from .serializers import TeamSerializer
        
        # Override department if not super admin to prevent cross-dept creation
        data = request.data.copy()
        if request.user.role != 'ADMIN':
            role_to_dept = {'PWD': 'ROAD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICAL'}
            data['department'] = role_to_dept.get(request.user.role)
            
        serializer = TeamSerializer(data=data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class TeamMemberManageView(APIView):
    """Add/remove a crew member from a team. Dept admins only for their own teams."""
    permission_classes = [permissions.IsAuthenticated]
    
    DASHBOARD_ROLES = ('ADMIN', 'PWD', 'SANITATION', 'ELECTRICITY', 'CREW')

    def post(self, request, pk):
        if request.user.role not in self.DASHBOARD_ROLES:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
            
        from .models import Team, CustomUser
        try:
            team = Team.objects.get(pk=pk)
            # Dept isolation
            if request.user.role != 'ADMIN':
                role_to_dept = {'PWD': 'ROAD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICAL'}
                if team.department != role_to_dept.get(request.user.role):
                    return Response({'error': 'You can only manage teams in your department'}, status=status.HTTP_403_FORBIDDEN)
                    
        except Team.DoesNotExist:
            return Response({'error': 'Team not found'}, status=status.HTTP_404_NOT_FOUND)
            
        action = request.data.get('action') # 'add' or 'remove'
        user_id = request.data.get('user_id')
        try:
            member = CustomUser.objects.get(id=user_id, role='CREW')
            
            # Ensure member belongs to same department
            if request.user.role != 'ADMIN':
                role_to_dept = {'PWD': 'ROAD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICAL'}
                if member.department != role_to_dept.get(request.user.role):
                    return Response({'error': 'Member belongs to a different department'}, status=status.HTTP_403_FORBIDDEN)

            if action == 'add':
                member.team = team
            elif action == 'remove':
                member.team = None
            else:
                return Response({'error': "Invalid action. Use 'add' or 'remove'."}, status=status.HTTP_400_BAD_REQUEST)
            member.save()
            return Response({'message': f'Member {action}ed successfully'})
        except CustomUser.DoesNotExist:
            return Response({'error': 'Crew member not found'}, status=status.HTTP_404_NOT_FOUND)

class CrewListView(APIView):
    """Admin-only view to list all field crew members."""
    permission_classes = [permissions.IsAuthenticated]

    DASHBOARD_ROLES = ('ADMIN', 'PWD', 'SANITATION', 'ELECTRICITY', 'CREW')

    def get(self, request):
        if request.user.role not in self.DASHBOARD_ROLES:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        
        from .serializers import UserSerializer
        
        # Map department role to Team.DEPARTMENT_CHOICES values
        role_to_dept = {'PWD': 'ROAD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICAL'}
        
        crew = CustomUser.objects.filter(role='CREW').select_related('team')
        
        if request.user.role != 'ADMIN':
            if request.user.role == 'CREW':
                crew_dept = request.user.department
            else:
                crew_dept = role_to_dept.get(request.user.role)
            crew = crew.filter(department=crew_dept)

        serializer = UserSerializer(crew, many=True)
        return Response(serializer.data)
