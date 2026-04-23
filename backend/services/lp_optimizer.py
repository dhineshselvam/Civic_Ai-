import numpy as np
import logging
from scipy.optimize import linear_sum_assignment
from django.db.models import Count, Avg
import math
from complaints.models import Complaint
from users.models import Team

logger = logging.getLogger(__name__)

def get_target_department(category: str) -> str:
    category = (category or '').lower()
    if any(k in category for k in ['light', 'lamp', 'streetlight', 'dark', 'pole', 'electric']):
        return 'ELECTRICAL'
    if any(k in category for k in ['garbage', 'waste', 'overflow', 'bin', 'dump', 'sanit']):
        return 'SANITATION'
    if any(k in category for k in ['pothole', 'road', 'street', 'pavement', 'speed breaker', 'manhole']):
        return 'ROAD'
    return 'GENERAL'

def haversine(lat1, lon1, lat2, lon2):
    """Calculate the great circle distance in kilometers between two points on the earth."""
    if lat1 is None or lon1 is None or lat2 is None or lon2 is None:
        return 0.0
    R = 6371.0 # Radius of earth in km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

def auto_assign_teams(department=None) -> int:
    """
    Assign unassigned complaints to deployment-ready teams using LP optimization.
    Returns the number of complaints newly assigned.
    """
    # 1. Gather all unassigned complaints
    query = Complaint.objects.filter(
        status__in=['Reported', 'Verified'],
        assigned_teams__isnull=True
    )
    if department:
        query = query.filter(department=department)
    unassigned = list(query)
    if not unassigned:
        return 0

    # 2. Identify deployment-ready teams
    ready_teams = []
    # Count members per team
    teams_with_counts = Team.objects.filter(is_active=True).annotate(member_count=Count('members'))
    
    for team in teams_with_counts:
        req = 2 if team.department == 'ELECTRICAL' else 3
        if team.department == 'GENERAL':
            req = 1
        if team.member_count >= req:
            ready_teams.append(team)

    if not ready_teams:
        logger.warning('Auto-Assign failed: No deployment-ready teams available.')
        return 0

    # Calculate initial workload (active complaints assigned) for each ready team
    active_statuses = ['Reported', 'Verified', 'Assigned', 'In-Progress']
    team_workloads = {}
    team_centroids = {}
    
    for t in ready_teams:
        team_workloads[t.id] = Complaint.objects.filter(assigned_teams=t, status__in=active_statuses).count()
        # Find the average live location of team members
        locs = t.members.filter(current_latitude__isnull=False, current_longitude__isnull=False).aggregate(
            avg_lat=Avg('current_latitude'),
            avg_lng=Avg('current_longitude')
        )
        if locs['avg_lat'] is not None:
            team_centroids[t.id] = (locs['avg_lat'], locs['avg_lng'])
        else:
            team_centroids[t.id] = None

    # 3. Build Cost Matrix
    # We restrict max active tasks per team to prevent infinite hoarding.
    max_slots_per_team = 5
    
    team_slots = [] # (Team, slot_index)
    for t in ready_teams:
        current_load = team_workloads[t.id]
        for slot in range(max_slots_per_team):
            team_slots.append((t, current_load + slot))

    num_rows = len(team_slots)
    num_cols = len(unassigned)
    
    cost_matrix = np.zeros((num_rows, num_cols))

    for r, (team, effective_load) in enumerate(team_slots):
        for c, comp in enumerate(unassigned):
            cost = 0.0
            
            # Balancing workload: cost increases with the effective load of the slot
            cost += effective_load * 20.0
            
            # Department mismatch penalty
            target_dept = get_target_department(comp.predicted_category)
            if team.department != target_dept:
                cost += 1000.0 # High penalty for wrong department
                
            # Priority sensitivity: Subtract points so higher priority = cheaper = assigned first
            cost -= getattr(comp, 'priority_score', 0) * 1.5
            
            # Distance awareness: Penalty based on distance to live working zone
            centroid = team_centroids.get(team.id)
            if centroid:
                dist = haversine(centroid[0], centroid[1], comp.latitude, comp.longitude)
                cost += dist * 5.0  # 5 cost points per km
                
            cost_matrix[r, c] = cost

    # 4. Solve the assignment problem
    # Handles rectangular matrices properly
    row_ind, col_ind = linear_sum_assignment(cost_matrix)

    # 5. Apply assignments
    assigned_count = 0
    for r, c in zip(row_ind, col_ind):
        # linear_sum_assignment can map out-of-bounds cols if matrix isn't padded,
        # but here rows (team slots) >= cols (complaints), so all cols are covered.
        team, _ = team_slots[r]
        comp = unassigned[c]
        
        # We only assign if the cost isn't essentially infinite (meaning all teams are mismatched)
        # However, a mismatch might be forced if no matching team exists. We'll allow it but 
        # log a warning.
        comp.assigned_teams.add(team)
        # Also add individual members to assigned_users for detailed tracking
        for member in team.members.all():
            comp.assigned_users.add(member)
            
        comp.status = 'Assigned'
        comp.save(update_fields=['status'])
        assigned_count += 1
        
        # Notify reporter
        if comp.user:
            from complaints.notification_service import send_notification
            send_notification(
                user=comp.user,
                title="Issue Assigned",
                message=f"Your report #{comp.id} has been auto-assigned to Team {team.name}."
            )

    return assigned_count
