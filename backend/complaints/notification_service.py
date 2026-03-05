import logging
import os
from users.models import Notification
# We import CustomUser inside the function to avoid circular imports if needed
# but since users depends on complaints, we should be careful.
# Actually, the Notification model is in the 'users' app.

logger = logging.getLogger(__name__)

def send_notification(user, title, message, notification_type='in_app'):
    """
    Truly free notification system.
    Saves to database for 'In-App' inbox.
    """
    try:
        if user and not user.is_anonymous:
            Notification.objects.create(
                user=user,
                title=title,
                message=message
            )
            logger.info(f"In-App Notification saved for {user.email}: {title}")
            return True
    except Exception as e:
        logger.error(f"Failed to save in-app notification: {str(e)}")
    
    # Fallback to console debug
    print(f"\n[FREE NOTIFICATION] {title}: {message}\n")
    return True
