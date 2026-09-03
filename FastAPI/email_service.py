import os
import json
import logging
import urllib.request
import urllib.error
from typing import Optional

logger = logging.getLogger("auramind.email_service")

RESEND_API_URL = "https://api.resend.com/emails"
DEFAULT_FROM_EMAIL = "onboarding@resend.dev"


def get_resend_api_key() -> str:
    """Retrieve Resend API key from environment variables."""
    return os.getenv("RESEND_API_KEY", "").strip()


def get_resend_from_email() -> str:
    """Retrieve sender email address for Resend."""
    return os.getenv("RESEND_FROM_EMAIL", DEFAULT_FROM_EMAIL).strip()


def send_emergency_checkin_email(
    to_email: str,
    friend_name: Optional[str] = None,
) -> bool:
    """
    Sends a supportive check-in message to the emergency contact using Resend.
    Returns True if successfully sent, False otherwise.
    Never throws an exception so caller flow is never interrupted.
    """
    to_email = (to_email or "").strip()
    if not to_email or "@" not in to_email:
        print(f"[Email Service] No valid emergency contact email provided ('{to_email}'). Skipping email.")
        logger.warning("No valid emergency contact email provided. Skipping email dispatch.")
        return False


    api_key = get_resend_api_key()
    if not api_key:
        print("[Email Service] RESEND_API_KEY is not configured. Skipping email.")
        logger.warning("RESEND_API_KEY is not configured. Skipping email dispatch.")
        return False

    from_email = get_resend_from_email()
    display_name = friend_name.strip() if friend_name and friend_name.strip() else "your friend"

    subject = "A gentle reminder to check up on your friend"

    text_body = (
        f"Hi there,\n\n"
        f"We are reaching out from AuraMind to suggest checking up on {display_name}. "
        f"They designated you as their trusted emergency contact.\n\n"
        f"Sending a warm message or giving them a brief call today could make a meaningful difference.\n\n"
        f"Warm regards,\n"
        f"The AuraMind Care Team"
    )

    html_body = f"""
    <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #2D3748; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #E2E8F0; border-radius: 8px;">
        <h2 style="color: #4A5568; margin-top: 0;">A gentle check-in reminder</h2>
        <p>Hi there,</p>
        <p>We are reaching out from AuraMind to gently suggest checking up on <strong>{display_name}</strong> today.</p>
        <p>They listed you as their trusted emergency contact. Reaching out with a warm text message, a kind word, or a brief call could make a meaningful difference.</p>
        <div style="margin-top: 24px; padding-top: 16px; border-top: 1px solid #E2E8F0; font-size: 13px; color: #718096;">
            <p>Warm regards,<br/><strong>The AuraMind Care Team</strong></p>
        </div>
    </div>
    """

    print(f"[Email Service] Sending emergency check-in email to {to_email} via Resend...")

    # Try sending via resend Python SDK if available
    try:
        import resend

        resend.api_key = api_key
        params = {
            "from": from_email,
            "to": [to_email],
            "subject": subject,
            "html": html_body,
            "text": text_body,
        }
        res = resend.Emails.send(params)
        print(f"[Email Service] SUCCESS! Email sent to {to_email}. Resend ID: {res}")
        logger.info("Emergency check-in email successfully sent to %s via Resend SDK: %s", to_email, res)
        return True
    except Exception as sdk_err:
        print(f"[Email Service] Resend SDK error: {sdk_err}. Trying HTTP REST API fallback...")
        logger.info("Resend SDK call failed (%s), trying standard HTTP REST API...", sdk_err)

    # Fallback to standard library HTTP POST
    try:
        payload = {
            "from": from_email,
            "to": [to_email],
            "subject": subject,
            "html": html_body,
            "text": text_body,
        }
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "User-Agent": "AuraMind-App",
        }
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            RESEND_API_URL,
            data=data,
            headers=headers,
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=10.0) as resp:
            if resp.status in (200, 201):
                resp_text = resp.read().decode("utf-8")
                print(f"[Email Service] SUCCESS via REST API! Response: {resp_text}")
                logger.info("Emergency check-in email successfully sent to %s via Resend REST API.", to_email)
                return True
            else:
                print(f"[Email Service] Resend API returned unexpected status {resp.status}")
                logger.error("Resend API returned status %s", resp.status)
                return False
    except urllib.error.HTTPError as exc:
        err_msg = exc.read().decode("utf-8", errors="ignore")
        print(f"[Email Service] Resend API HTTP error ({exc.code}): {err_msg}")
        logger.error("Resend API HTTP error (%s): %s", exc.code, err_msg)
        return False
    except Exception as exc:
        print(f"[Email Service] Exception sending email: {exc}")
        logger.error("Failed to send Resend emergency alert email: %s", exc)
        return False


def send_practitioner_suicide_alert_email(
    to_email: str,
    user_name: str,
    user_email: str,
) -> bool:
    """Notify a clinician connected to the user when a risk scan is positive."""
    to_email = (to_email or "").strip()
    if not to_email or "@" not in to_email:
        return False
    api_key = get_resend_api_key()
    if not api_key:
        logger.warning("RESEND_API_KEY is not configured; practitioner alert skipped")
        return False
    subject = "AuraMind safety alert: please contact your patient"
    text_body = (
        f"A suicide-risk signal was detected in a journal entry from {user_name} ({user_email}).\n\n"
        "Please contact the person promptly and follow your clinical safety protocol. "
        "This automated alert is not a diagnosis."
    )
    payload = {
        "from": get_resend_from_email(),
        "to": [to_email],
        "subject": subject,
        "text": text_body,
        "html": f"<p>A suicide-risk signal was detected in a journal entry from <strong>{user_name}</strong> ({user_email}).</p><p>Please contact the person promptly and follow your clinical safety protocol.</p><p>This automated alert is not a diagnosis.</p>",
    }
    try:
        request = urllib.request.Request(
            RESEND_API_URL,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=10.0) as response:
            return response.status in (200, 201)
    except Exception as exc:
        logger.error("Failed to send practitioner safety alert: %s", exc)
        return False
