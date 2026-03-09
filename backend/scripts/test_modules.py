import os
import sys
import django
from datetime import datetime, timedelta
from django.utils import timezone

# Setup Django environment
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from users.models import CustomUser, Team
from complaints.models import Complaint
from services.lp_optimizer import auto_assign_teams
from django.core.files.uploadedfile import SimpleUploadedFile

def run_tests():
    print("--- Starting Module Tests ---")

    # 1. Setup Teams and Crew
    Team.objects.all().delete()
    CustomUser.objects.filter(role='CREW').delete()
    Complaint.objects.all().delete()

    print("Creating Teams...")
    road_team = Team.objects.create(name="Road Warriors", department="ROAD")
    san_team = Team.objects.create(name="Trash Bashers", department="SANITATION")
    elec_team = Team.objects.create(name="Spark Pluggers", department="ELECTRICAL")

    print("Registering 10 Crew Members...")
    for i in range(1, 4):  # 3 Road
        u = CustomUser.objects.create_user(username=f'road_guy_{i}', email=f'r{i}@test.com', password='pw', role='CREW', department='ROAD')
        u.team = road_team
        u.save()
    for i in range(1, 6):  # 5 Sanitation
        u = CustomUser.objects.create_user(username=f'san_guy_{i}', email=f's{i}@test.com', password='pw', role='CREW', department='SANITATION')
        u.team = san_team
        u.save()
    for i in range(1, 3):  # 2 Electrical
        u = CustomUser.objects.create_user(username=f'elec_guy_{i}', email=f'e{i}@test.com', password='pw', role='CREW', department='ELECTRICAL')
        u.team = elec_team
        u.save()

    print(f"Created {CustomUser.objects.filter(role='CREW').count()} CREW assigned to Teams.")

    # 2. Test Priority Engine (Complaint Creation)
    # We will bypass the views and test the model save method directly which calls recompute_priority
    print("\nCreating Submissions (Testing Priority Engine)...")
    comp1 = Complaint.objects.create(
        description="Massive pothole causing accidents",
        latitude=40.7128,
        longitude=-74.0060,
        timestamp=timezone.now() - timedelta(hours=10), # Submitted at night? Maybe.
        predicted_category="Large Pothole",
        address="123 Road Ave",
        image_hash="aaaa1111",
    )
    # Reload from DB to see priority
    comp1.refresh_from_db()
    print(f"Complaint 1 [Pothole, Danger words]: Score = {comp1.priority_score}, Label = {comp1.priority_label}")
    assert comp1.priority_score > 50, "Priority should be boosted due to danger keywords"

    # 3. Test Duplicate Checking logic 
    # Simulated upvoting as duplicate checker would do in the view
    print("\nSimulating Duplicate Report from another citizen...")
    comp1.upvote_count += 3
    comp1.recompute_priority()
    comp1.save()
    comp1.refresh_from_db()
    print(f"Complaint 1 [Upvoted]: Score = {comp1.priority_score}, Label = {comp1.priority_label}")
    # It should have +9 points due to 3 additional upvotes
    
    # 4. Insert multiple unassigned complaints
    comp2 = Complaint.objects.create(
        description="Garbage overflowing near the park",
        latitude=40.7130,
        longitude=-74.0065,
        timestamp=timezone.now(),
        predicted_category="Garbage Pile",
        image_hash="aaaa2222",
    )
    comp3 = Complaint.objects.create(
        description="Streetlight flickering",
        latitude=40.7140,
        longitude=-74.0075,
        timestamp=timezone.now(),
        predicted_category="Broken Streetlight",
        image_hash="aaaa3333",
    )
    comp4 = Complaint.objects.create(
        description="Another pothole",
        latitude=40.7150,
        longitude=-74.0080,
        timestamp=timezone.now(),
        predicted_category="Pothole",
        image_hash="aaaa4444",
    )

    unassigned = Complaint.objects.filter(assigned_teams__isnull=True).count()
    print(f"\nThere are {unassigned} unassigned complaints.")

    # 5. Test LP Optimizer
    print("\nRunning LP Auto-Assign...")
    assigned_count = auto_assign_teams()
    print(f"Assign logic completed. newly assigned: {assigned_count}")
    
    comp1.refresh_from_db()
    comp2.refresh_from_db()
    comp3.refresh_from_db()
    comp4.refresh_from_db()

    print("Assignments Results:")
    print(f"Comp 1 (Pothole): Teams = {[t.name for t in comp1.assigned_teams.all()]}")
    print(f"Comp 2 (Garbage): Teams = {[t.name for t in comp2.assigned_teams.all()]}")
    print(f"Comp 3 (Streetlight): Teams = {[t.name for t in comp3.assigned_teams.all()]}")
    print(f"Comp 4 (Pothole 2): Teams = {[t.name for t in comp4.assigned_teams.all()]}")

    assert comp1.assigned_teams.filter(department='ROAD').exists(), "Comp 1 should go to Road"
    assert comp2.assigned_teams.filter(department='SANITATION').exists(), "Comp 2 should go to Sanitation"
    assert comp3.assigned_teams.filter(department='ELECTRICAL').exists(), "Comp 3 should go to Electrical"

    print("\n--- ALL TESTS PASSED ---")

if __name__ == "__main__":
    run_tests()
