from .views import (
    ReportIssueView,
    ComplaintListView,
    ComplaintDetailView,
    DashboardStatsView,
    CityAnalyticsView,
    CrewListView,
    HighPriorityView,
    AutoAssignView,
)
from django.urls import path

urlpatterns = [
    path('report-issue/', ReportIssueView.as_view(), name='report-issue'),
    path('complaints/', ComplaintListView.as_view(), name='complaint-list'),
    path('complaints/<int:pk>/', ComplaintDetailView.as_view(), name='complaint-detail'),
    path('complaints/<int:pk>/feedback/', ComplaintDetailView.as_view(), name='complaint-feedback'),
    path('complaints/<int:pk>/assign/', ComplaintDetailView.as_view(), name='complaint-assign'),
    path('complaints/<int:pk>/auto-assign/', AutoAssignView.as_view(), name='complaint-auto-assign'),
    path('dashboard/stats/', DashboardStatsView.as_view(), name='dashboard-stats'),
    path('analytics/', CityAnalyticsView.as_view(), name='city-analytics'),
    path('crew/', CrewListView.as_view(), name='crew-list'),
    path('high-priority/', HighPriorityView.as_view(), name='high-priority'),
]
