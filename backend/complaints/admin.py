from django.contrib import admin
from .models import Complaint


@admin.register(Complaint)
class ComplaintAdmin(admin.ModelAdmin):
    list_display = ('id', 'predicted_category', 'latitude', 'longitude', 'created_at')
    list_filter = ('predicted_category',)
    search_fields = ('description', 'predicted_category')
