import logging
import os
import tempfile

from django.utils import timezone
from rest_framework import status
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework.views import APIView

from .clip_service import classify_issue
from .models import Complaint
from .serializers import ComplaintCreateSerializer, ComplaintResponseSerializer

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

        complaint = Complaint(
            image=image,
            description=description,
            latitude=latitude,
            longitude=longitude,
            timestamp=timestamp,
            predicted_category=predicted_category,
        )
        complaint.save()

        response_serializer = ComplaintResponseSerializer(data={
            'message': 'Complaint submitted successfully',
            'predicted_category': predicted_category,
        })
        response_serializer.is_valid(raise_exception=True)
        return Response(response_serializer.validated_data, status=status.HTTP_201_CREATED)
