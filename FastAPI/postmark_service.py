"""Backward compatibility alias for email_service."""
from email_service import (
    send_emergency_checkin_email,
    get_resend_api_key,
    get_resend_from_email,
)

__all__ = [
    "send_emergency_checkin_email",
    "get_resend_api_key",
    "get_resend_from_email",
]
