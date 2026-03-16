"""
Script: create_departments.py
Creates department staff users in the database for PWD, SANITATION, and ELECTRICITY.

Usage:
    python scripts/create_departments.py
"""
import os
import sys
import django

# Initialise Django
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
django.setup()

from users.models import CustomUser  # noqa: E402 (must be after django.setup)


DEPARTMENT_USERS = [
    # (username, email, password, role, department)
    ("pwd_admin",         "pwd@civic.gov",         "pwd@1234",   "PWD",         "ROAD"),
    ("sanitation_admin",  "sanitation@civic.gov",  "san@1234",   "SANITATION",  "SANITATION"),
    ("electricity_admin", "electricity@civic.gov", "elec@1234",  "ELECTRICITY", "ELECTRICAL"),
]


def ensure_user(username, email, password, role, department):
    user, created = CustomUser.objects.get_or_create(username=username)
    user.email = email
    user.role = role
    user.department = department
    user.is_active = True
    user.set_password(password)
    user.save()
    status = "Created" if created else "Updated"
    print(f"  [{status}] {role} user: {username}  (dept={department})")


if __name__ == "__main__":
    print("Creating department users...")
    for args in DEPARTMENT_USERS:
        ensure_user(*args)
    print("Done.")
