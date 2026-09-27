import os
import httpx


class SMSService:
    """
    SMS service for SmartProcure.
    Keeps the SMS provider credentials on the backend.
    """

    def __init__(self):
        self.auth_key = os.getenv("MSG91_AUTH_KEY")
        self.template_id = os.getenv("MSG91_TEMPLATE_ID")

    async def send_otp(self, mobile: str, otp: str) -> bool:
        mobile = mobile.strip()

        # Convert +91XXXXXXXXXX to XXXXXXXXXX
        if mobile.startswith("+91"):
            mobile = mobile[3:]

        # Convert 91XXXXXXXXXX to XXXXXXXXXX
        if mobile.startswith("91") and len(mobile) == 12:
            mobile = mobile[2:]

        # Validate Indian mobile number
        if len(mobile) != 10 or not mobile.isdigit():
            raise ValueError("Invalid Indian mobile number")

        if not self.auth_key:
            raise RuntimeError("MSG91_AUTH_KEY is not configured")

        if not self.template_id:
            raise RuntimeError("MSG91_TEMPLATE_ID is not configured")

        url = "https://control.msg91.com/api/v5/otp"

        headers = {
            "authkey": self.auth_key,
            "Content-Type": "application/json",
        }

        payload = {
            "template_id": self.template_id,
            "mobile": f"91{mobile}",
            "otp": otp,
        }

        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                url,
                headers=headers,
                json=payload,
            )

        if response.is_success:
            return True

        print(
            f"MSG91 SMS failed: "
            f"{response.status_code} - {response.text}"
        )

        return False


# This is the object imported by auth.py
sms_service = SMSService()