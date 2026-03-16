import numpy as np
import logging
from scipy.optimize import linear_sum_assignment
from django.db.models import Count
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
    for t in ready_teams:
        team_workloads[t.id] = Complaint.objects.filter(assigned_teams=t, status__in=active_statuses).count()

    # 3. Build Cost Matrix
    # We allow each team to take up to N tasks simultaneously to ensure LP has enough rows.
    # N could be the number of unassigned complaints.
    max_slots_per_team = len(unassigned)
    
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
            cost += effective_load * 10.0
            
            # Department mismatch penalty
            target_dept = get_target_department(comp.predicted_category)
            if team.department != target_dept:
                cost += 1000.0 # High penalty for wrong department
                
            cost_matrix[r, c] = cost

    # 4. Solve the assignment problem
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
