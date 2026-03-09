import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from complaints.views import CityAnalyticsView
from users.models import CustomUser
from django.test import RequestFactory
import traceback

factory = RequestFactory()
request = factory.get('/api/analytics/')
request.user = CustomUser.objects.filter(role='ADMIN').first()

if not request.user:
    print("NO ADMIN USER FOUND to test with")
else:
    try:
        view = CityAnalyticsView()
        response = view.get(request)
        print("Success! Response:", response.data)
    except Exception as e:
        print("CRASH DETECTED. Traceback:")
        traceback.print_exc()
