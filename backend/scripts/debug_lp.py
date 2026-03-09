import os
import django

import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from users.models import Team
from django.db.models import Count
from services.lp_optimizer import get_target_department

print('--- Teams ---')
for t in Team.objects.annotate(c=Count('members')):
    print(t.name, t.department, t.c)

print('Streetlight target:', get_target_department('Broken Streetlight'))
