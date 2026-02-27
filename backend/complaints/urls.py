from django.urls import path

from . import views

urlpatterns = [
    path('report-issue/', views.ReportIssueView.as_view(), name='report-issue'),
]
