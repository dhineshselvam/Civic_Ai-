import logging
import os
import tempfile

from django.utils import timezone
from django.db.models import Q
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

            genuinity_status = 'Unverified'
            try:
                import piexif
                from math import radians, sin, cos, sqrt, atan2

                def _rational_to_float(val):
                    """Convert a piexif rational (tuple of two ints) or plain number to float."""
                    if isinstance(val, tuple) and len(val) == 2:
                        return float(val[0]) / float(val[1]) if val[1] else 0.0
                    return float(val)

                def _dms_to_decimal(dms_tuple, ref):
                    """Convert a DMS tuple ((d,d),(m,m),(s,s)) + ref string to signed decimal degrees."""
                    deg  = _rational_to_float(dms_tuple[0])
                    min_ = _rational_to_float(dms_tuple[1])
                    sec  = _rational_to_float(dms_tuple[2])
                    dec  = deg + (min_ / 60.0) + (sec / 3600.0)
                    ref_str = ref.decode('utf-8', 'ignore') if isinstance(ref, bytes) else str(ref)
                    return -dec if ref_str.strip().upper() in ('S', 'W') else dec

                exif_dict = piexif.load(tmp_path)
                gps_info  = exif_dict.get("GPS", {})
                logger.debug(f"[Genuinity] Raw GPS EXIF keys: {list(gps_info.keys())}")
                logger.debug(f"[Genuinity] Full GPS EXIF data: {gps_info}")

                # piexif key constants: 1=LatRef, 2=Lat, 3=LngRef, 4=Lng
                exif_lat = exif_lng = None

                if 2 in gps_info and gps_info[2]:
                    lat_ref = gps_info.get(1, b'N')
                    exif_lat = _dms_to_decimal(gps_info[2], lat_ref)
                    logger.debug(f"[Genuinity] Extracted EXIF lat={exif_lat} (ref={lat_ref})")

                if 4 in gps_info and gps_info[4]:
                    lng_ref = gps_info.get(3, b'E')
                    exif_lng = _dms_to_decimal(gps_info[4], lng_ref)
                    logger.debug(f"[Genuinity] Extracted EXIF lng={exif_lng} (ref={lng_ref})")

                if exif_lat is not None and exif_lng is not None:
                    R = 6371000
                    phi1 = radians(float(latitude))
                    phi2 = radians(exif_lat)
                    dphi = radians(exif_lat - float(latitude))
                    dlam = radians(exif_lng - float(longitude))
                    a = sin(dphi / 2.0) ** 2 + cos(phi1) * cos(phi2) * sin(dlam / 2.0) ** 2
                    distance = R * 2 * atan2(sqrt(a), sqrt(1 - a))

                    logger.debug(
                        f"[Genuinity] Input coords=({latitude}, {longitude}), "
                        f"EXIF coords=({exif_lat}, {exif_lng}), distance={distance:.1f}m"
                    )

                    if distance < 500:
                        genuinity_status = 'Verified'
                        logger.info(f"[Genuinity] VERIFIED – distance {distance:.1f}m < 500m")
                    else:
                        genuinity_status = 'Flagged'
                        logger.info(f"[Genuinity] FLAGGED – distance {distance:.1f}m >= 500m")
                else:
                    logger.info("[Genuinity] No valid GPS coordinates found in EXIF – status remains Unverified")

            except Exception as e:
                import traceback
                logger.warning(f"[Genuinity] EXIF parsing failed: {e}\n{traceback.format_exc()}")

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
                'genuinity_status': genuinity_status,
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
            genuinity_status=genuinity_status,
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
            # SUBMITTED
            send_notification(
                user=complaint.user,
                title="Complaint Submitted",
                message=(
                    f"Your complaint #{complaint.id} has been successfully submitted. "
                    f"The issue is identified as {predicted_category} and will be reviewed shortly."
                ),
                notification_type='in_app'
            )
            # UNDER_REVIEW — fires immediately when genuinity_status is Unverified
            if genuinity_status == 'Unverified':
                send_notification(
                    user=complaint.user,
                    title="Complaint Under Review",
                    message=(
                        f"Your complaint #{complaint.id} is under review. "
                        f"We are currently verifying the submitted details."
                    ),
                    notification_type='in_app'
                )

        response_serializer = ComplaintResponseSerializer(data={
            'message': 'Complaint submitted successfully',
            'predicted_category': predicted_category,
            'complaint_id': complaint.id,
            'priority_score': complaint.priority_score,
            'priority_label': complaint.priority_label,
            'genuinity_status': genuinity_status,
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
                 # User sees tasks assigned specifically to them OR their teams
                 complaints = complaints.filter(Q(assigned_users=user) | Q(assigned_teams__members=user)).distinct()

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
                old_genuinity = complaint.genuinity_status
                serializer.save()
                new_genuinity = request.data.get('genuinity_status')
                if complaint.user:
                    if new_genuinity == 'Verified' and old_genuinity != 'Verified':
                        # VERIFIED
                        send_notification(
                            user=complaint.user,
                            title="Complaint Verified",
                            message=(
                                f"Your complaint #{complaint.id} has been verified and approved. "
                                f"It will now be processed."
                            ),
                        )
                    elif new_genuinity == 'Flagged' and old_genuinity != 'Flagged':
                        # REJECTED
                        send_notification(
                            user=complaint.user,
                            title="Complaint Rejected",
                            message=(
                                f"Your complaint #{complaint.id} was rejected due to invalid details. "
                                f"Please resubmit with correct information."
                            ),
                        )
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
            team_id = request.data.get('team_id')
            
            is_admin = request.user.role == 'ADMIN'
            is_dept_admin = request.user.role in ('PWD', 'SANITATION', 'ELECTRICITY')

            if (crew_username or team_id) and (is_admin or is_dept_admin):
                from users.models import CustomUser, Team
                
                # Helper to check department match
                def check_dept_match(obj_dept, is_team=False):
                    if not is_dept_admin: return True
                    dept_map = {'PWD': 'PWD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICITY'}
                    role_to_crew_dept = {'PWD': 'ROAD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICAL'}
                    my_dept = dept_map.get(request.user.role)
                    my_target_dept = role_to_crew_dept.get(request.user.role)
                    if complaint.department != my_dept: return False
                    return obj_dept == my_target_dept

                if team_id:
                    try:
                        team = Team.objects.get(pk=team_id)
                        if not check_dept_match(team.department, is_team=True):
                            return Response({'error': 'You can only assign teams from your department'}, status=status.HTTP_403_FORBIDDEN)
                        
                        complaint.assigned_teams.add(team)
                        # Add all team members
                        members = CustomUser.objects.filter(team=team)
                        for m in members:
                            complaint.assigned_users.add(m)
                            send_notification(user=m, title="New Team Task", message=f"Your team has been assigned: {complaint.predicted_category}.")
                        
                        complaint.status = 'Assigned'
                        complaint.save()
                        log_activity(request.user, f"Assigned complaint #{complaint.id} to team '{team.name}'")
                    except Team.DoesNotExist:
                        return Response({'error': 'Team not found'}, status=status.HTTP_404_NOT_FOUND)

                elif crew_username:
                    try:
                        crew_member = CustomUser.objects.get(username=crew_username, role='CREW')
                        if not check_dept_match(crew_member.department):
                             return Response({'error': 'Unauthorized department assignment'}, status=status.HTTP_403_FORBIDDEN)

                        if crew_member.team:
                            complaint.assigned_teams.add(crew_member.team)
                        complaint.assigned_users.add(crew_member)
                        complaint.status = 'Assigned'
                        complaint.save()
                        log_activity(request.user, f"Assigned complaint #{complaint.id} to crew member '{crew_username}'")
                        send_notification(user=crew_member, title="New Task Assigned", message=f"You have been assigned: {complaint.predicted_category}.")
                    except CustomUser.DoesNotExist:
                        return Response({'error': 'Crew member not found'}, status=status.HTTP_404_NOT_FOUND)
            
            new_status = request.data.get('status')
            if new_status and new_status != old_status:
                # Permission Check: Only Admins, Dept Admins, or Supervisors can change status
                is_admin = request.user.role == 'ADMIN'
                is_dept_admin = request.user.role in ('PWD', 'SANITATION', 'ELECTRICITY')
                is_supervisor = getattr(request.user, 'is_supervisor', False)

                if not (is_admin or is_dept_admin or is_supervisor):
                    return Response({'error': 'Unauthorized: Only supervisors or admins can update issue status.'}, 
                                  status=status.HTTP_403_FORBIDDEN)
                
                complaint.status = new_status
                log_activity(request.user, f"Updated complaint #{complaint.id} status to '{new_status}'")
                # Credibility: verified genuine reports earn a bonus
                if complaint.user and old_status == 'Reported' and new_status == 'Verified':
                    reporter = complaint.user
                    reporter.trust_score = min(100, reporter.trust_score + 10)
                    reporter.save(update_fields=['trust_score'])

                if complaint.user:
                    if new_status == 'Resolved':
                        # RESOLVED
                        send_notification(
                            user=complaint.user,
                            title="Complaint Resolved",
                            message=(
                                f"Your complaint #{complaint.id} has been successfully resolved. "
                                f"Please verify the resolution."
                            ),
                        )
                        # FEEDBACK_REQUEST
                        send_notification(
                            user=complaint.user,
                            title="Share Your Feedback",
                            message=(
                                f"Please rate your experience for complaint #{complaint.id}. "
                                f"Your feedback helps us improve."
                            ),
                        )
                    else:
                        # Generic fallback for any other status change
                        send_notification(
                            user=complaint.user,
                            title=f"Status Update: {new_status}",
                            message=f"The status of your complaint #{complaint.id} is now {new_status}.",
                        )
            
            complaint.save()
            return Response(ComplaintSerializer(complaint).data)
        except Complaint.DoesNotExist:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

    def delete(self, request, pk):
        """
        DELETE /api/complaints/<id>/
        Permanently removes a resolved spam complaint.
        Restricted to Admin and Department roles only.
        """
        is_admin = request.user.is_authenticated and request.user.role == 'ADMIN'
        is_dept_admin = request.user.is_authenticated and request.user.role in ('PWD', 'SANITATION', 'ELECTRICITY')

        if not (is_admin or is_dept_admin):
            return Response({'error': 'Only admins or department users can remove reports.'}, status=status.HTTP_403_FORBIDDEN)

        try:
            complaint = Complaint.objects.get(pk=pk)
        except Complaint.DoesNotExist:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

        # Only allow deletion of resolved spam complaints
        if complaint.status != 'Resolved':
            return Response({'error': 'Only resolved complaints can be removed.'}, status=status.HTTP_400_BAD_REQUEST)
        if complaint.predicted_category.lower() != 'spam':
            return Response({'error': 'Only spam-category complaints can be removed.'}, status=status.HTTP_400_BAD_REQUEST)

        # Department users can only delete from their own department
        if is_dept_admin:
            dept_map = {'PWD': 'PWD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICITY'}
            if complaint.department != dept_map.get(request.user.role):
                return Response({'error': 'You can only remove spam reports from your department.'}, status=status.HTTP_403_FORBIDDEN)

        log_activity(request.user, f"Permanently removed resolved spam complaint #{complaint.id}")
        complaint.delete()
        return Response({'message': f'Spam report #{pk} removed successfully.'}, status=status.HTTP_204_NO_CONTENT)


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

        # SLA breach: backward-compatible fallback – Low priority unresolved > 72h (3 days)
        sla_threshold = tz.now() - timedelta(days=3)
        sla_breaches = qs.filter(
            created_at__lt=sla_threshold,
            status__in=['Reported', 'Verified']
        ).count()

        # --- Dynamic SLA stats (new tier-based logic) ---
        now = tz.now()
        near_threshold = now + timedelta(minutes=60)

        # Complaints whose stored sla_deadline has already passed (active only)
        dynamic_sla_breaches = qs.filter(
            status__in=['Reported', 'Verified'],
            sla_deadline__isnull=False,
            sla_deadline__lte=now,
        ).count()

        # Complaints within 60 min of their deadline (not yet breached)
        near_deadline_count = qs.filter(
            status__in=['Reported', 'Verified'],
            sla_deadline__isnull=False,
            sla_deadline__gt=now,
            sla_deadline__lte=near_threshold,
        ).count()

        # (priority score might have been escalated naturally or by SLA system)
        escalated_count = qs.filter(
            status__in=['Reported', 'Verified'],
            sla_breach_notified=False,
            priority_label='Critical',
        ).exclude(priority_score__lt=80).count()
        # Simpler approximation: count complaints whose sla_breach_logs exist
        from complaints.models import SLABreachLog
        escalated_count = SLABreachLog.objects.filter(
            complaint__in=qs.filter(status__in=['Reported', 'Verified']),
            reason__icontains='Escalated',
        ).values('complaint').distinct().count()

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
        # (Already calculated above, using the scoped crew_qs)
        pass

        return Response({
            'total_reports': total,
            'active_reports': active,
            'resolved_reports': resolved,
            'crew_count': crew_count,
            'user_count': user_count,
            'high_priority_count': high_priority_count,
            # Legacy 3-day SLA breach count (backward compatible)
            'sla_breaches': sla_breaches,
            # New dynamic tier-based SLA counts
            'dynamic_sla_breaches': dynamic_sla_breaches,
            'near_deadline_count': near_deadline_count,
            'escalated_count': escalated_count,
            'avg_resolution_days': avg_resolution_days,
            'top_categories': top_categories,
            'crew_available': crew_available,
        })


class SLABreachLogListView(APIView):
    """
    GET /api/complaints/sla-breach-logs/
    Returns the 50 most recent SLA breach/escalation log entries.
    Accessible to Admin and Department roles only.
    """
    permission_classes = [permissions.IsAuthenticated]
    DASHBOARD_ROLES = ('ADMIN', 'PWD', 'SANITATION', 'ELECTRICITY')

    def get(self, request):
        if request.user.role not in self.DASHBOARD_ROLES:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)

        from complaints.models import SLABreachLog

        role = request.user.role
        logs_qs = SLABreachLog.objects.select_related('complaint').order_by('-timestamp')

        # Scope to department for non-admin users
        if role != 'ADMIN':
            dept_map = {'PWD': 'PWD', 'SANITATION': 'SANITATION', 'ELECTRICITY': 'ELECTRICITY'}
            dept = dept_map.get(role)
            if dept:
                logs_qs = logs_qs.filter(complaint__department=dept)

        logs_qs = logs_qs[:50]
        data = [
            {
                'id': log.id,
                'complaint_id': log.complaint_id,
                'complaint_category': log.complaint.predicted_category,
                'complaint_status': log.complaint.status,
                'complaint_priority': log.complaint.priority_label,
                'timestamp': log.timestamp.isoformat(),
                'reason': log.reason,
            }
            for log in logs_qs
        ]
        return Response(data)


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


# ---------------------------------------------------------------------------
# Predictive Analysis – module-level model cache (loaded once per process)
# ---------------------------------------------------------------------------
_PRED_MODELS_CACHE: dict = {}

def _load_predictive_models() -> dict:
    """Load RF + encoders from ml_training/ – cached after first call."""
    global _PRED_MODELS_CACHE
    if _PRED_MODELS_CACHE:
        return _PRED_MODELS_CACHE

    import joblib
    import os

    ml_dir = os.path.join(os.path.dirname(__file__), '..', 'ml_training')

    rf_path  = os.path.join(ml_dir, 'predictive_rf_model.pkl')
    enc_path = os.path.join(ml_dir, 'zone_encoder.pkl')
    thr_path = os.path.join(ml_dir, 'zone_risk_thresholds.pkl')
    cen_path = os.path.join(ml_dir, 'zone_monthly_centroids.pkl')
    hot_path = os.path.join(ml_dir, 'zone_hotspots.pkl')

    if not all(os.path.exists(p) for p in [rf_path, enc_path, thr_path]):
        raise FileNotFoundError(
            "Predictive model files not found. "
            "Run: python ml_training/train_predictive_model.py"
        )

    _PRED_MODELS_CACHE = {
        'rf':         joblib.load(rf_path),
        'zone_enc':   joblib.load(enc_path),
        'thresholds': joblib.load(thr_path),
        'centroids':  joblib.load(cen_path) if os.path.exists(cen_path) else {},
        'hotspots':   joblib.load(hot_path) if os.path.exists(hot_path) else {},
    }
    logger.info("Predictive models loaded and cached.")
    return _PRED_MODELS_CACHE


class PredictiveAnalysisView(APIView):
    """
    GET /api/predictions/?month=<1-12>

    Returns a JSON list – one entry per zone – with:
      zone, predicted_issue, expected_complaints, risk_level

    Role-based filtering:
      ADMIN        → all 6 zones, all issue types
      PWD          → all zones, but predicted_issue forced to Pothole filter
      SANITATION   → all zones, Garbage filter
      ELECTRICITY  → all zones, Streetlight filter
    """
    permission_classes = [permissions.IsAuthenticated]

    ALLOWED_ROLES = ('ADMIN', 'PWD', 'SANITATION', 'ELECTRICITY')

    DEPT_ISSUE_MAP = {
        'PWD':        'Pothole',
        'SANITATION': 'Garbage',
        'ELECTRICITY': 'Streetlight',
    }

    # Zones with their approximate centroids (for reference / ordering)
    ZONES = [
        'White Town',
        'Lawspet',
        'Muthialpet',
        'Reddiarpalayam',
        'Ariyankuppam',
        'Villianur',
    ]

    # Representative street-level addresses for each zone
    ZONE_ADDRESSES = {
        'White Town':     'Rue de la Marine, White Town, Puducherry - 605001',
        'Lawspet':        '100 Feet Road, Lawspet, Puducherry - 605008',
        'Muthialpet':     'Bussy Street, Muthialpet, Puducherry - 605003',
        'Reddiarpalayam': 'Reddiarpalayam Main Road, Puducherry - 605010',
        'Ariyankuppam':   'Ariyankuppam Village Road, Puducherry - 605007',
        'Villianur':      'Villianur Main Road, Puducherry - 605110',
    }

    def get(self, request):
        role = getattr(request.user, 'role', None)
        if role not in self.ALLOWED_ROLES:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)

        # Parse month parameter (default: current month)
        from datetime import date as _date
        current_month = _date.today().month
        try:
            month = int(request.query_params.get('month', current_month))
            if not 1 <= month <= 12:
                raise ValueError
        except (ValueError, TypeError):
            return Response({'error': 'month must be 1–12'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            models = _load_predictive_models()
        except FileNotFoundError as exc:
            return Response({'error': str(exc)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        except Exception as exc:
            logger.exception("Failed to load predictive models")
            return Response({'error': str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        rf         = models['rf']
        zone_enc   = models['zone_enc']
        thresholds = models['thresholds']
        centroids  = models['centroids']   # zone → {'monthly': {m: {'lat':, 'lng':}}, 'fallback': {...}}
        hotspots   = models['hotspots']    # zone → month → issue → [{'lat', 'lng', 'weight'}, ...]

        # Dept filter for non-admin roles
        dept_issue  = self.DEPT_ISSUE_MAP.get(role)   # None for ADMIN

        results = []
        for zone in self.ZONES:
            # -----------------------------------------------------------------
            # A. Expected complaints for this month from historical stats
            # -----------------------------------------------------------------
            zone_thr = thresholds.get(zone, {})
            monthly_avg = zone_thr.get('monthly_avg', {})
            expected = round(monthly_avg.get(month, 0))

            # -----------------------------------------------------------------
            # B. Risk level from historical percentile thresholds
            # -----------------------------------------------------------------
            p33 = zone_thr.get('p33', 0)
            p66 = zone_thr.get('p66', 0)
            if expected >= p66:
                risk_level = 'High'
            elif expected >= p33:
                risk_level = 'Medium'
            else:
                risk_level = 'Low'

            # -----------------------------------------------------------------
            # C. Predicted issue type from RF model
            # -----------------------------------------------------------------
            try:
                zone_code = zone_enc.transform([zone])[0]
            except Exception:
                zone_code = 0

            # Use peak daytime hour (10 AM) and Monday (0) as representative input
            X_pred = [[zone_code, month, 10, 0]]
            predicted_issue = rf.predict(X_pred)[0]

            # Get probabilities for all issues
            try:
                probas = rf.predict_proba(X_pred)[0]
                issue_probs = {
                    str(rf.classes_[i]): round(float(probas[i]) * 100, 1)
                    for i in range(len(rf.classes_))
                }
                # Sort exactly by probability descending
                issue_probs = dict(sorted(issue_probs.items(), key=lambda item: item[1], reverse=True))
            except Exception:
                issue_probs = {}

            # -----------------------------------------------------------------
            # D. Dept filtering – skip zones where issue doesn't match
            # -----------------------------------------------------------------
            if dept_issue is not None and predicted_issue != dept_issue:
                # Override predicted issue with dept-specific one
                # (still return zone so map shows it, but with dept label)
                predicted_issue = dept_issue

            # -----------------------------------------------------------------
            # E. Dynamic lat/lng centroid for this zone × month
            # -----------------------------------------------------------------
            zone_cent    = centroids.get(zone, {})
            monthly_cents = zone_cent.get('monthly', {})
            fallback_cent = zone_cent.get('fallback', {'lat': 11.934, 'lng': 79.833})
            cent = monthly_cents.get(month, fallback_cent)

            # -----------------------------------------------------------------
            # F. Exact hotspot locations for this zone × month × predicted_issue
            # -----------------------------------------------------------------
            zone_month_hotspots = hotspots.get(zone, {}).get(month, {})
            # Use predicted_issue as the issue key; fall back to any available issue
            hotspot_list = zone_month_hotspots.get(predicted_issue, [])
            if not hotspot_list:
                # Try to find any issue's hotspots as fallback
                for _spots in zone_month_hotspots.values():
                    if _spots:
                        hotspot_list = _spots
                        break

            # Normalize hotspot weights so they sum exactly to the zone's expected complaints
            if expected == 0:
                hotspot_list = []
            elif hotspot_list:
                raw_sum = sum(h.get('weight', 0) for h in hotspot_list)
                if raw_sum > 0:
                    normalized_hotspots = []
                    remaining = expected
                    sorted_hotspots = sorted(hotspot_list, key=lambda x: x.get('weight', 0), reverse=True)
                    
                    for i, h in enumerate(sorted_hotspots):
                        if i == len(sorted_hotspots) - 1:
                            scaled_weight = remaining
                        else:
                            scaled_weight = int(round((h.get('weight', 0) / raw_sum) * expected))
                            if scaled_weight <= 0 and remaining > (len(sorted_hotspots) - i - 1):
                                scaled_weight = 1
                            remaining -= scaled_weight
                        
                        new_h = dict(h)
                        new_h['weight'] = max(0, scaled_weight)
                        normalized_hotspots.append(new_h)
                    hotspot_list = normalized_hotspots

            results.append({
                'zone':                zone,
                'predicted_issue':     predicted_issue,
                'issue_probabilities': issue_probs,
                'expected_complaints': expected,
                'risk_level':          risk_level,
                'address':             self.ZONE_ADDRESSES.get(zone, zone + ', Puducherry'),
                'latitude':            cent['lat'],
                'longitude':           cent['lng'],
                'hotspots':            hotspot_list,   # list of {lat, lng, weight}
            })

        return Response(results, status=status.HTTP_200_OK)




