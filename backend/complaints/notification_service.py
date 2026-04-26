import logging
import os
from users.models import Notification

logger = logging.getLogger(__name__)

# Valid notification type choices (mirror Notification.NOTIFICATION_TYPE_CHOICES)
_VALID_TYPES = {'general', 'response_warning', 'resolution_warning', 'breach'}


def send_notification(user, title, message, notification_type='general'):
    """
    Save an in-app notification to the database.

    Parameters
    ----------
    user             : CustomUser instance
    title            : str
    message          : str
    notification_type: one of 'general' | 'response_warning' |
                       'resolution_warning' | 'breach'
    """
    resolved_type = notification_type if notification_type in _VALID_TYPES else 'general'
    try:
        if user and not user.is_anonymous:
            n = Notification.objects.create(
                user=user,
                title=title,
                message=message,
                type=resolved_type,
            )
            logger.info(
                "[NOTIFICATION SAVED] pk=%s user=%s type=%s title=%r",
                n.pk, user.email, resolved_type, title,
            )
            return True
    except Exception as e:
        logger.error(
            "[NOTIFICATION FAILED] user=%s type=%s title=%r error=%s",
            getattr(user, 'email', 'unknown'),
            resolved_type,
            title,
            str(e),
            exc_info=True,
        )

    # Fallback to console debug (anonymous / unauthenticated)
    print(f"\n[FREE NOTIFICATION] [{resolved_type}] {title}: {message}\n")
    return True

