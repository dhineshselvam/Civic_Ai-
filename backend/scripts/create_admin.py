# (venv) PS C:\Civic_Ai-\backend> python -m scripts.create_admin

import os
import sys
import django

# Add backend folder to Python path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

# Set Django settings module
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
django.setup()

from users.models import CustomUser

def create_admin(username, email, password):
    if not CustomUser.objects.filter(username=username).exists():
        CustomUser.objects.create_superuser(
            username=username,
            email=email,
            password=password,
            role='ADMIN'
        )
        print(f"Admin user '{username}' created successfully.")
    else:
        user = CustomUser.objects.get(username=username)
        user.role = 'ADMIN'
        user.is_superuser = True
        user.is_staff = True
        user.save()
        print(f"User '{username}' already exists. Role updated to ADMIN.")

if __name__ == "__main__":
    create_admin('admin2', 'admin1@civicai.com', 'admin@123')
