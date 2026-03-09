# c:\Civic_Ai-\backend\venv\Scripts\python.exe c:\Civic_Ai-\backend\scripts\seed_crew.py


import os
import sys
import django

# Add the parent directory (backend root) to the Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from users.models import CustomUser, Team

def seed():
    # 1. Ensure Teams exist for each department
    depts = [
        ('ROAD', 'ROAD_CREW_1', 5),
        ('ROAD', 'ROAD_CREW_2', 4),
        ('SANITATION', 'TEAM_CLEAN_1', 4),
        ('ELECTRICAL', 'POWER_GRID_1', 4),
        ('ELECTRICAL', 'POWER_GRID_2', 3),
    ]

    for dept_code, team_name, member_count in depts:
        team, _ = Team.objects.get_or_create(name=team_name, department=dept_code)
        print(f"Team: {team_name} ({dept_code})")
        
        # Add members
        for i in range(1, member_count + 1):
            username = f"{team_name.lower()}_member_{i}"
            email = f"{username}@civic.ai"
            if not CustomUser.objects.filter(username=username).exists():
                try:
                    user = CustomUser.objects.create_user(
                        username=username,
                        email=email,
                        password='password123',
                        role='CREW',
                        department=dept_code,
                        team=team
                    )
                    print(f"  Created member: {username}")
                except Exception as e:
                    print(f"  Skipped {username} (already exists or error)")
            else:
                print(f"  Member already exists: {username}")

if __name__ == "__main__":
    seed()
