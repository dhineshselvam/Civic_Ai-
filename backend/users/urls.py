from django.urls import path
from .views import (
    RegisterView, 
    LoginView, 
    UserProfileView, 
    NotificationListView,
    PasswordResetRequestView,
    PasswordResetConfirmView,
    CrewRegistrationView
)

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('profile/', UserProfileView.as_view(), name='user_profile'),
    path('notifications/', NotificationListView.as_view(), name='notifications'),
    path('password-reset/request/', PasswordResetRequestView.as_view(), name='password_reset_request'),
    path('password-reset/confirm/', PasswordResetConfirmView.as_view(), name='password_reset_confirm'),
    path('register-crew/', CrewRegistrationView.as_view(), name='register_crew'),
]
