from django.urls import path
from .views import (
    RegisterView,
    LoginView,
    UserProfileView,
    ActivityLogView,
    NotificationListView,
    NotificationDetailView,
    PasswordResetRequestView,
    PasswordResetConfirmView,
    CrewRegistrationView,
    TeamListView,
    TeamMemberManageView,
    CrewListView
)

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('profile/', UserProfileView.as_view(), name='user_profile'),
    path('notifications/', NotificationListView.as_view(), name='notifications'),
    path('notifications/<int:pk>/read/', NotificationDetailView.as_view(), name='notification_read'),
    path('password-reset/request/', PasswordResetRequestView.as_view(), name='password_reset_request'),
    path('password-reset/confirm/', PasswordResetConfirmView.as_view(), name='password_reset_confirm'),
    path('register-crew/', CrewRegistrationView.as_view(), name='register_crew'),
    path('crew-list/', CrewListView.as_view(), name='crew_list'),
    path('teams/', TeamListView.as_view(), name='team_list'),
    path('teams/<int:pk>/members/', TeamMemberManageView.as_view(), name='team_member_manage'),
    path('activity-log/', ActivityLogView.as_view(), name='activity_log'),
]
