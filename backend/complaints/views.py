import logging
import os
import tempfile

from django.utils import timezone
from rest_framework import status, permissions
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework.views import APIView

from .clip_service import classify_issue
from .models import Complaint, UserReport
from services.duplicate_checker import compute_image_hash, find_nearby_duplicate
from .notification_service import send_notification
from users.models import log_activity
from .serializers import (
    ComplaintCreateSerializer, 
    ComplaintResponseSerializer, 
    ComplaintSerializer,
    ComplaintFeedbackSerializer,
    UserReportSerializer
)

logger = logging.getLogger(__name__)


class ReportIssueView(APIView):
    """
    POST /api/report-issue/
    Accepts multipart/form-data: image, description, latitude, longitude, timestamp.
    Runs CLIP classification, saves complaint, returns message and predicted_category.
    """
    parser_classes = (MultiPartParser, FormParser)

    def post(self, request):
        serializer = ComplaintCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        image = request.FILES.get('image')
        if not image:
            return Response(
                {'error': 'image is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        description = serializer.validated_data['description']
        latitude = serializer.validated_data['latitude']
        longitude = serializer.validated_data['longitude']
        timestamp = serializer.validated_data['timestamp']

        if timezone.is_naive(timestamp):
            timestamp = timezone.make_aware(timestamp)

        tmp_path = None
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(image.name)[1] or '.jpg') as tmp:
                tmp_path = tmp.name
                for chunk in image.chunks():
                    tmp.write(chunk)
                image.seek(0)

            predicted_category = classify_issue(tmp_path, description)

            # Duplicate detection using perceptual hashing
            img_hash = compute_image_hash(tmp_path)
            duplicate = None
            if img_hash:
                duplicate = find_nearby_duplicate(
                    latitude=latitude,
                    longitude=longitude,
                    image_hash_hex=img_hash,
                )
        except FileNotFoundError:
            logger.exception("CLIP model not found")
            return Response(
                {'error': 'Classification service unavailable (model not found).'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        except Exception as e:
            logger.exception("Classification failed")
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
        finally:
            if tmp_path and os.path.exists(tmp_path):
                try:
                    os.unlink(tmp_path)
                except OSError:
                    pass

        address = request.data.get('address', '')

        user = request.user if request.user.is_authenticated else None

        # If a similar unresolved complaint exists nearby, map report to that issue
        if duplicate is not None:
            existing = duplicate.complaint
            existing.upvote_count = (existing.upvote_count or 1) + 1
            existing.recompute_priority()
            # Also store/refresh image hash if missing
            if not existing.image_hash and img_hash:
                existing.image_hash = img_hash
            existing.save()
            
            # Create the individual UserReport
            UserReport.objects.create(
                complaint=existing,
                user=user,
                image=image,
                description=description,
                latitude=latitude,
                longitude=longitude,
                timestamp=timestamp,
                address=address,
                is_original=False
            )

            # Credibility impact: if the same citizen keeps re-reporting
            # their own already-open issue, treat as a minor self-duplicate.
            if user:
                # Increment contribution count regardless
                user.reports_count += 1
                # If the duplicate belongs to the same user, nudge trust down
                if existing.user_id == user.id:
                    user.trust_score = max(0, user.trust_score - 10)
                user.save(update_fields=['reports_count', 'trust_score'])

            response_serializer = ComplaintResponseSerializer(data={
                'message': 'A similar issue already exists nearby; your report increased its priority.',
                'predicted_category': existing.predicted_category,
                'complaint_id': existing.id,
                'priority_score': existing.priority_score,
                'priority_label': existing.priority_label,
            })
            response_serializer.is_valid(raise_exception=True)
            return Response(response_serializer.validated_data, status=status.HTTP_200_OK)

        # It's a brand new issue
        complaint = Complaint(
            image=image, # Save image on base complaint too backward-compat
            description=description,
            latitude=latitude,
            longitude=longitude,
            timestamp=timestamp,
            predicted_category=predicted_category,
            address=address,
            image_hash=img_hash,
            user=user,
        )
        complaint.save()
        
        # Create the individual UserReport for the original reporter
        UserReport.objects.create(
            complaint=complaint,
            user=user,
            image=image,
            description=description,
            latitude=latitude,
            longitude=longitude,
            timestamp=timestamp,
            address=address,
            is_original=True
        )

        if complaint.user:
            send_notification(
                user=complaint.user,
                title="Report Received",
                message=(
                    f"Report #{complaint.id} classified as '{predicted_category}' "
                    f"with {complaint.priority_label} priority."
                ),
                notification_type='in_app'
            )

        response_serializer = ComplaintResponseSerializer(data={
            'message': 'Complaint submitted successfully',
            'predicted_category': predicted_category,
            'complaint_id': complaint.id,
            'priority_score': complaint.priority_score,
            'priority_label': complaint.priority_label,
        })
        response_serializer.is_valid(raise_exception=True)
        return Response(response_serializer.validated_data, status=status.HTTP_201_CREATED)


class ComplaintListView(APIView):
    """
    GET /api/complaints/
    Returns a list of all complaints.
    For CITIZEN role: returns only their own complaints.
    For ADMIN role: returns all complaints (with optional status filter).
    For CREW role: returns complaints assigned to them.
    """
    def get(self, request):
        complained_by_me = request.query_params.get('mine')
        assigned_to_me = request.query_params.get('assigned_to_me')
        status_filter = request.query_params.get('status')
        all_submissions = request.query_params.get('all_submissions')

        if (assigned_to_me == 'true' or request.user.role == 'CREW') and request.user.is_authenticated:
            # Crew see complaints filtered by their department
            user = request.user
            crew_dept = getattr(user, 'department', None)
            if crew_dept:
                # Map CustomUser.department (Team.DEPARTMENT_CHOICES) → Complaint.department
                dept_map = {
                    'ROAD': 'PWD',
                    'SANITATION': 'SANITATION',
                    'ELECTRICAL': 'ELECTRICITY',
                }
                complaint_dept = dept_map.get(crew_dept, crew_dept)
                complaints = Complaint.objects.filter(department=complaint_dept)
            else:
                # Fallback: complaints assigned to their team
                complaints = Complaint.objects.filter(assigned_teams__members=user)
            
            # If specifically looking for assigned tasks
            if assigned_to_me == 'true':
                 complaints = complaints.filter(assigned_users=user)

            if status_filter:
                complaints = complaints.filter(status=status_filter)
            serializer = ComplaintSerializer(complaints, many=True, context={'request': request})
            return Response(serializer.data)
            
        elif request.user.is_authenticated and request.user.role == 'CITIZEN' or complained_by_me == 'true':
            # Citizens see their individual submissions (User Report Layer)
            reports = UserReport.objects.filter(user=request.user)
            if status_filter:
                reports = reports.filter(complaint__status=status_filter)
            serializer = UserReportSerializer(reports, many=True, context={'request': request})
            return Response(serializer.data)
            
        elif request.user.is_authenticated and request.user.role == 'ADMIN':
            if all_submissions == 'true':
                # Admin views All Submissions (User Report Layer)
                reports = UserReport.objects.all()
                if status_filter:
                    reports = reports.filter(complaint__status=status_filter)
                serializer = UserReportSerializer(reports, many=True, context={'request': request})
                return Response(serializer.data)
            else:
                # Admin views unique issues (Unique Layer) - all departments
                complaints = Complaint.objects.all()
                if status_filter:
                    complaints = complaints.filter(status=status_filter)
                serializer = ComplaintSerializer(complaints, many=True, context={'request': request})
                return Response(serializer.data)

        elif request.user.is_authenticated and request.user.role in ('PWD', 'SANITATION', 'ELECTRICITY'):
            # Department users see only their department's complaints
            dept_map = {'PWD': 'PWD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICITY'}
            department = dept_map[request.user.role]
            if all_submissions == 'true':
                reports = UserReport.objects.filter(complaint__department=department)
                if status_filter:
                    reports = reports.filter(complaint__status=status_filter)
                serializer = UserReportSerializer(reports, many=True, context={'request': request})
                return Response(serializer.data)
            else:
                complaints = Complaint.objects.filter(department=department)
                if status_filter:
                    complaints = complaints.filter(status=status_filter)
                serializer = ComplaintSerializer(complaints, many=True, context={'request': request})
                return Response(serializer.data)

        else:
            complaints = Complaint.objects.all()
            if status_filter:
                complaints = complaints.filter(status=status_filter)
            serializer = ComplaintSerializer(complaints, many=True, context={'request': request})
            return Response(serializer.data)


class ComplaintDetailView(APIView):
    """
    GET /api/complaints/<id>/ - View details
    PATCH /api/complaints/<id>/feedback/ - Submit rating/feedback
    POST /api/complaints/<id>/assign/ - Assign to crew (Admin only)
    """
    def get(self, request, pk):
        try:
            complaint = Complaint.objects.get(pk=pk)
            serializer = ComplaintSerializer(complaint, context={'request': request})
            data = serializer.data
            
            # Embed the user reports associated with this complaint
            user_reports = complaint.user_reports.all()
            data['reports'] = UserReportSerializer(user_reports, many=True, context={'request': request}).data
            
            return Response(data)
        except Complaint.DoesNotExist:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

    def patch(self, request, pk):
        try:
            complaint = Complaint.objects.get(pk=pk)
            # Specific permission check for editing
            is_admin = request.user.role == 'ADMIN'
            is_dept_admin = request.user.role in ('PWD', 'SANITATION', 'ELECTRICITY')
            
            if 'rating' in request.data:
                serializer = ComplaintFeedbackSerializer(complaint, data=request.data, partial=True)
            elif is_admin:
                serializer = ComplaintSerializer(complaint, data=request.data, partial=True)
            elif is_dept_admin:
                # Check department
                dept_map = {'PWD': 'PWD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICITY'}
                if complaint.department != dept_map.get(request.user.role):
                    return Response({'error': 'You can only edit issues in your department'}, status=status.HTTP_403_FORBIDDEN)
                serializer = ComplaintSerializer(complaint, data=request.data, partial=True)
            else:
                return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)
                
            if serializer.is_valid():
                serializer.save()
                return Response({'message': 'Update successful', 'data': serializer.data})
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        except Complaint.DoesNotExist:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

    def post(self, request, pk):
        """Assign to crew member or update status."""
        try:
            complaint = Complaint.objects.get(pk=pk)
            old_status = complaint.status
            
            # Assignment logic
            crew_username = request.data.get('assigned_to')
            is_admin = request.user.role == 'ADMIN'
            is_dept_admin = request.user.role in ('PWD', 'SANITATION', 'ELECTRICITY')

            if crew_username and (is_admin or is_dept_admin):
                from users.models import CustomUser
                try:
                    crew_member = CustomUser.objects.get(username=crew_username, role='CREW')
                    
                    # If dept admin, ensure department match for both issue and crew
                    if is_dept_admin:
                        dept_map = {'PWD': 'PWD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICITY'}
                        role_to_crew_dept = {'PWD': 'ROAD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICAL'}
                        
                        my_dept = dept_map.get(request.user.role)
                        my_crew_dept = role_to_crew_dept.get(request.user.role)
                        
                        if complaint.department != my_dept:
                             return Response({'error': 'You can only assign crew to your department issues'}, status=status.HTTP_403_FORBIDDEN)
                        if crew_member.department != my_crew_dept:
                             return Response({'error': 'You can only assign crew members from your department'}, status=status.HTTP_403_FORBIDDEN)

                    if crew_member.team:
                        complaint.assigned_teams.add(crew_member.team)
                    
                    # Also add individual user to assigned_users for detailed tracking
                    complaint.assigned_users.add(crew_member)
                    
                    complaint.status = 'Assigned'
                    complaint.save()
                    log_activity(request.user, f"Assigned complaint #{complaint.id} to crew member '{crew_username}'")
                    
                    if complaint.user:
                        send_notification(
                            user=complaint.user,
                            title="Issue Assigned",
                            message=f"Your report #{complaint.id} has been assigned to our field crew.",
                        )
                    
                    send_notification(
                        user=crew_member,
                        title="New Task Assigned",
                        message=f"You have been assigned a new task: {complaint.predicted_category}.",
                    )
                except CustomUser.DoesNotExist:
                    return Response({'error': 'Crew member not found'}, status=status.HTTP_404_NOT_FOUND)
            
            new_status = request.data.get('status')
            if new_status and new_status != old_status:
                complaint.status = new_status
                log_activity(request.user, f"Updated complaint #{complaint.id} status to '{new_status}'")
                # Credibility: verified genuine reports earn a bonus
                if complaint.user and old_status == 'Reported' and new_status == 'Verified':
                    reporter = complaint.user
                    reporter.trust_score = min(100, reporter.trust_score + 10)
                    reporter.save(update_fields=['trust_score'])

                if complaint.user:
                    send_notification(
                        user=complaint.user,
                        title=f"Status Update: {new_status}",
                        message=f"The status of your report #{complaint.id} is now {new_status}.",
                    )
            
            complaint.save()
            return Response(ComplaintSerializer(complaint).data)
        except Complaint.DoesNotExist:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

class DashboardStatsView(APIView):
    """GET /api/complaints/dashboard/stats/ - Rich KPIs for admin and department users."""
    permission_classes = [permissions.IsAuthenticated]

    # Roles that have access to this dashboard
    DASHBOARD_ROLES = ('ADMIN', 'PWD', 'SANITATION', 'ELECTRICITY', 'CREW')

    def get(self, request):
        if request.user.role not in self.DASHBOARD_ROLES:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)

        from users.models import CustomUser
        from django.db.models import Count
        from datetime import timedelta
        from django.utils import timezone as tz

        # Scope complaints to department for non-admin users
        role = request.user.role
        if role != 'ADMIN':
            if role == 'CREW':
                # Map CustomUser.department -> Complaint.department
                crew_dept_map = {'ROAD': 'PWD', 'SANITATION': 'SANITATION', 'ELECTRICAL': 'ELECTRICITY'}
                dept = crew_dept_map.get(request.user.department, 'GENERAL')
            else:
                dept_map = {'PWD': 'PWD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICITY'}
                dept = dept_map.get(role, 'GENERAL')
            
            qs = Complaint.objects.filter(department=dept)
        else:
            qs = Complaint.objects.all()

        total = qs.count()
        resolved = qs.filter(status='Resolved').count()
        active = total - resolved
        # Crew counts - scope to dept if not admin
        if role != 'ADMIN':
            role_to_crew_dept = {'PWD': 'ROAD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICAL'}
            if role == 'CREW':
                crew_dept = request.user.department  # already stored as ROAD/SANITATION/ELECTRICAL
            else:
                crew_dept = role_to_crew_dept.get(role)
            crew_qs = CustomUser.objects.filter(role='CREW', department=crew_dept) if crew_dept else CustomUser.objects.none()
        else:
            crew_qs = CustomUser.objects.filter(role='CREW')
            
        crew_count = crew_qs.count()
        crew_available = crew_count
        user_count = CustomUser.objects.filter(role='CITIZEN').count()

        # High priority unresolved
        high_priority_count = qs.filter(
            priority_label__in=['High', 'Critical'],
            status__in=['Reported', 'Verified', 'Assigned', 'In-Progress']
        ).count()

        # SLA breach: unresolved and open > 3 days
        sla_threshold = tz.now() - timedelta(days=3)
        sla_breaches = qs.filter(
            created_at__lt=sla_threshold,
            status__in=['Reported', 'Verified']
        ).count()

        # Average resolution time in days
        resolved_complaints = qs.filter(status='Resolved')
        avg_resolution_days = None
        if resolved_complaints.exists():
            durations = [
                (c.updated_at - c.created_at).total_seconds() / 86400
                for c in resolved_complaints
            ]
            avg_resolution_days = round(sum(durations) / len(durations), 1)

        # Top 3 categories
        top_categories = list(
            qs.values('predicted_category')
            .annotate(count=Count('id'))
            .order_by('-count')[:3]
        )

        # Crew available
        # (Alread calculated above, using the scoped crew_qs)
        pass

        return Response({
            'total_reports': total,
            'active_reports': active,
            'resolved_reports': resolved,
            'crew_count': crew_count,
            'user_count': user_count,
            'high_priority_count': high_priority_count,
            'sla_breaches': sla_breaches,
            'avg_resolution_days': avg_resolution_days,
            'top_categories': top_categories,
            'crew_available': crew_available,
        })


class HighPriorityView(APIView):
    """GET /api/complaints/high-priority/ - Top urgent unresolved issues."""
    permission_classes = [permissions.IsAuthenticated]

    DASHBOARD_ROLES = ('ADMIN', 'PWD', 'SANITATION', 'ELECTRICITY', 'CREW')

    def get(self, request):
        if request.user.role not in self.DASHBOARD_ROLES:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)

        # Start with all active complaints
        qs = Complaint.objects.filter(status__in=['Reported', 'Verified', 'Assigned', 'In-Progress'])

        role = request.user.role
        if role != 'ADMIN':
            if role == 'CREW':
                crew_dept_map = {'ROAD': 'PWD', 'SANITATION': 'SANITATION', 'ELECTRICAL': 'ELECTRICITY'}
                dept = crew_dept_map.get(request.user.department, 'GENERAL')
            else:
                dept_map = {'PWD': 'PWD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICITY'}
                dept = dept_map.get(role, 'GENERAL')
            qs = qs.filter(department=dept)

        issues = qs.order_by('-priority_score', '-created_at')[:8]
        return Response(ComplaintSerializer(issues, many=True, context={'request': request}).data)



class AutoAssignView(APIView):
    """
    POST /api/complaints/auto-assign/
    Automatically pick the 'best' teams for all unassigned complaints based on LP Optimization.
    Admin only.
    """
    permission_classes = [permissions.IsAuthenticated]

    DASHBOARD_ROLES = ('ADMIN', 'PWD', 'SANITATION', 'ELECTRICITY', 'CREW')

    def post(self, request, pk=None):
        if request.user.role not in self.DASHBOARD_ROLES:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)

        from services.lp_optimizer import auto_assign_teams
        
        # Scope optimization to the user's department if they are not a super admin
        optimization_dept = None
        if request.user.role != 'ADMIN':
            if request.user.role == 'CREW':
                crew_dept_map = {'ROAD': 'PWD', 'SANITATION': 'SANITATION', 'ELECTRICAL': 'ELECTRICITY'}
                optimization_dept = crew_dept_map.get(request.user.department, 'GENERAL')
            else:
                role_to_dept = {'PWD': 'PWD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICITY'}
                optimization_dept = role_to_dept.get(request.user.role)

        try:
            # Run optimization for the specific department (or global if admin)
            assigned_count = auto_assign_teams(department=optimization_dept)
            
            msg = f'Optimization complete. Successfully assigned {assigned_count} complaints.'
            log_activity(request.user, f"Ran auto-assign optimizer (assigned {assigned_count} complaints)")
            if pk:
                from complaints.models import Complaint
                try:
                    comp = Complaint.objects.get(pk=pk)
                    teams = comp.assigned_teams.all()
                    if teams.exists():
                        team_names = ", ".join(t.name for t in teams)
                        msg = f'Issue #{pk} assigned to {team_names}.'
                    else:
                        msg = f'Issue #{pk} could not be automatically assigned. (Not enough crew or mismatch).'
                except Complaint.DoesNotExist:
                    pass

            return Response({
                'message': msg,
                'assigned_count': assigned_count
            }, status=status.HTTP_200_OK)
        except Exception as e:
            logger.exception("LP Auto-assign failed")
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)



class CityAnalyticsView(APIView):
    """GET /api/analytics/ - Analytics data for admin and department users."""
    permission_classes = [permissions.IsAuthenticated]

    DASHBOARD_ROLES = ('ADMIN', 'PWD', 'SANITATION', 'ELECTRICITY', 'CREW')

    def get(self, request):
        if request.user.role not in self.DASHBOARD_ROLES:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        
        from django.db.models import Count, Avg, F
        from datetime import timedelta
        from django.utils import timezone as tz

        # Scope to department for non-admin users
        role = request.user.role
        if role != 'ADMIN':
            if role == 'CREW':
                # Map CustomUser.department -> Complaint.department
                crew_dept_map = {'ROAD': 'PWD', 'SANITATION': 'SANITATION', 'ELECTRICAL': 'ELECTRICITY'}
                dept = crew_dept_map.get(request.user.department, 'GENERAL')
            else:
                dept_map = {'PWD': 'PWD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICITY'}
                dept = dept_map.get(role, 'GENERAL')
            
            qs = Complaint.objects.filter(department=dept)
        else:
            qs = Complaint.objects.all()

        # Category breakdown
        category_data = (
            qs.values('predicted_category')
            .annotate(count=Count('id'))
            .order_by('-count')
        )

        # Status breakdown
        status_data = (
            qs.values('status')
            .annotate(count=Count('id'))
        )

        # Average resolution time in days (Resolved complaints)
        resolved_complaints = qs.filter(status='Resolved')
        avg_resolution_days = None
        if resolved_complaints.exists():
            durations = [
                (c.updated_at - c.created_at).total_seconds() / 86400
                for c in resolved_complaints
            ]
            avg_resolution_days = round(sum(durations) / len(durations), 1)

        # Last 7 days report trend
        now = tz.now()
        trend = []
        for i in range(6, -1, -1):
            day = now - timedelta(days=i)
            count = qs.filter(created_at__date=day.date()).count()
            trend.append({'date': day.strftime('%d %b'), 'count': count})

        # Department workload (crew)
        from users.models import CustomUser
        dept_load = []
        
        # Scope crew workload to department if user is not admin
        crew_qs = CustomUser.objects.filter(role='CREW').exclude(department=None)
        if role != 'ADMIN':
            # Map dash role or crew dept to user.department value
            if role == 'CREW':
                target_crew_dept = request.user.department
            else:
                role_to_crew_dept = {'PWD': 'ROAD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICAL'}
                target_crew_dept = role_to_crew_dept.get(role)
            
            if target_crew_dept:
                crew_qs = crew_qs.filter(department=target_crew_dept)

        for crew in crew_qs:
            assigned = Complaint.objects.filter(assigned_teams__members=crew).distinct().count()
            resolved_c = Complaint.objects.filter(assigned_teams__members=crew, status='Resolved').distinct().count()
            dept_load.append({
                'username': crew.username,
                'department': crew.department,
                'assigned': assigned,
                'resolved': resolved_c,
            })

        # Map data for interactive visualization
        map_data = []
        for c in qs:
            map_data.append({
                'id': c.id,
                'latitude': c.latitude,
                'longitude': c.longitude,
                'predicted_category': c.predicted_category,
                'description': c.description,
                'status': c.status,
                'department': c.department,
                'created_at': c.created_at.isoformat() if c.created_at else None,
            })

        return Response({
            'category_breakdown': list(category_data),
            'status_breakdown': list(status_data),
            'avg_resolution_days': avg_resolution_days,
            'daily_trend': trend,
            'crew_workload': dept_load,
            'map_data': map_data,
        })


class CrewListView(APIView):
    """GET /api/crew/ - List crew members. Admins see all; department users see their dept crew."""
    permission_classes = [permissions.IsAuthenticated]

    DASHBOARD_ROLES = ('ADMIN', 'PWD', 'SANITATION', 'ELECTRICITY', 'CREW')

    def get(self, request):
        if request.user.role not in self.DASHBOARD_ROLES:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        
        from users.models import CustomUser
        from users.serializers import UserSerializer

        # Map department role → the `department` stored on CustomUser (Team.DEPARTMENT_CHOICES)
        role_to_dept = {'PWD': 'ROAD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICAL'}

        crew = CustomUser.objects.filter(role='CREW')
        if request.user.role != 'ADMIN':
            # Filter crew by the department that maps to this user's role
            crew_dept = role_to_dept[request.user.role]
            crew = crew.filter(department=crew_dept)
        else:
            # Admin can also filter by optional ?department= query param
            department = request.query_params.get('department')
            if department:
                crew = crew.filter(department=department)
        
        return Response(UserSerializer(crew, many=True).data)

class ManageAssignmentView(APIView):
    """
    POST /api/complaints/<id>/manage-crew/
    Granular control over assignments.
    Body: { "action": "add"|"remove"|"swap", "user_id": 123, "swap_with_id": 456 }
    """
    DASHBOARD_ROLES = ('ADMIN', 'PWD', 'SANITATION', 'ELECTRICITY', 'CREW')

    def post(self, request, pk):
        if request.user.role not in self.DASHBOARD_ROLES:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        
        try:
            complaint = Complaint.objects.get(pk=pk)
            # Permission check: department admins can only manage their own department's issues
            if request.user.role != 'ADMIN':
                dept_map = {'PWD': 'PWD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICITY'}
                expected_dept = dept_map.get(request.user.role)
                if complaint.department != expected_dept:
                    return Response({'error': 'You can only manage issues for your department'}, status=status.HTTP_403_FORBIDDEN)

            action = request.data.get('action')
            user_id = request.data.get('user_id')
            
            from users.models import CustomUser
            
            if action == 'add':
                user = CustomUser.objects.get(pk=user_id, role='CREW')
                complaint.assigned_users.add(user)
                if complaint.status == 'Reported' or complaint.status == 'Verified':
                    complaint.status = 'Assigned'
                complaint.save()
                send_notification(user, "New Task", f"You've been added to task #{complaint.id}")
                
            elif action == 'remove':
                user = CustomUser.objects.get(pk=user_id)
                complaint.assigned_users.remove(user)
                complaint.save()
                
            elif action == 'swap':
                old_user = CustomUser.objects.get(pk=user_id)
                new_user_id = request.data.get('swap_with_id')
                new_user = CustomUser.objects.get(pk=new_user_id, role='CREW')
                
                complaint.assigned_users.remove(old_user)
                complaint.assigned_users.add(new_user)
                complaint.save()
                send_notification(new_user, "Task Swapped", f"You've been assigned task #{complaint.id} (swapped)")
            
            return Response(ComplaintSerializer(complaint, context={'request': request}).data)
        except (Complaint.DoesNotExist, CustomUser.DoesNotExist):
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
