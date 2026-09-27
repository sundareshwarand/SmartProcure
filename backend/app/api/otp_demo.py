# SmartProcure OTP Demo Support
# Temporary development/SIH-demo OTP flow.
# Replace with Firebase/MSG91/Twilio before production.

from datetime import datetime, timedelta
import secrets

OTP_STORE = {}

OTP_EXPIRY_MINUTES = 5


def generate_demo_otp(mobile: str) -> str:
    mobile = str(mobile).strip()

    # Fixed development OTP prevents repeated manual-test failures.
    # Production must use a real SMS provider.
    otp = "123456"

    OTP_STORE[mobile] = {
        "otp": otp,
        "expires_at": datetime.utcnow() + timedelta(
            minutes=OTP_EXPIRY_MINUTES
        ),
        "verified": False,
    }

    return otp


def verify_demo_otp(mobile: str, otp: str) -> bool:
    mobile = str(mobile).strip()
    otp = str(otp).strip()

    record = OTP_STORE.get(mobile)

    if record is None:
        return False

    if datetime.utcnow() > record["expires_at"]:
        OTP_STORE.pop(mobile, None)
        return False

    if secrets.compare_digest(record["otp"], otp):
        record["verified"] = True
        return True

    return False
