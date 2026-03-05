import os, django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
django.setup()

from users.models import CustomUser

def ensure_user(username, email, password, role="CITIZEN", department=None):
    user, created = CustomUser.objects.get_or_create(username=username)
    user.email = email
    user.role = role
    user.department = department
    user.is_active = True
    user.set_password(password)   # <<< hashes the password
    user.save()
    print(f"{'Created' if created else 'Updated'} {role} user '{username}'")

if __name__ == "__main__":
    ensure_user("citizen1", "citizen1@example.com", "test1234", "CITIZEN")
    ensure_user("crew1", "crew1@example.com", "test1234", "CREW", department="ROAD")