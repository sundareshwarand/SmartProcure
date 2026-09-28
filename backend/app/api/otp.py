from datetime import datetime, timedelta
import random

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel


router = APIRouter(
    prefix="/api/v1/otp",
    tags=["OTP"],
)


# Demo OTP storage.
# For production, replace this with Redis/database + SMS provider.
otp_store = {}


class SendOTPRequest(BaseModel):
    phone: str


class VerifyOTPRequest(BaseModel):
    phone: str
    otp: str


@router.post("/send")
def send_otp(request: SendOTPRequest):

    phone = request.phone.strip()

    if not phone:
        raise HTTPException(
            status_code=400,
            detail="Phone number is required",
        )

    otp = str(random.randint(100000, 999999))

    otp_store[phone] = {
        "otp": otp,
        "expires_at": datetime.utcnow() + timedelta(minutes=5),
    }

    # Demo mode:
    # In production this OTP must be sent through
    # Firebase/Twilio/MSG91/AWS SNS/etc.
    print(f"[DEMO OTP] {phone} -> {otp}")

    return {
        "success": True,
        "message": "OTP generated successfully",
        "expires_in": 300,
        "demo_otp": otp,
    }


@router.post("/verify")
def verify_otp(request: VerifyOTPRequest):

    phone = request.phone.strip()
    otp = request.otp.strip()

    record = otp_store.get(phone)

    if not record:
        raise HTTPException(
            status_code=400,
            detail="OTP not found or expired",
        )

    if datetime.utcnow() > record["expires_at"]:
        otp_store.pop(phone, None)

        raise HTTPException(
            status_code=400,
            detail="OTP expired",
        )

    if record["otp"] != otp:
        raise HTTPException(
            status_code=400,
            detail="Invalid OTP",
        )

    otp_store.pop(phone, None)

    return {
        "success": True,
        "message": "OTP verified successfully",
        "phone": phone,
        "verified": True,
    }
