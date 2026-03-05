from django.contrib import admin

from .models import Complaint


@admin.register(Complaint)
class ComplaintAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'predicted_category',
        'priority_score',
        'priority_label',
        'upvote_count',
        'status',
        'created_at',
    )
    list_filter = ('predicted_category', 'status', 'priority_label')
    search_fields = ('description', 'predicted_category', 'address')
