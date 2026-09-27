from datetime import datetime, timedelta
import random

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel


router = APIRouter(
    prefix="/api/v1/otp",
    tags=["OTP"],
)


OTP_STORE = {}


class OTPSendRequest(BaseModel):
    mobile: str


class OTPVerifyRequest(BaseModel):
    mobile: str
    otp: str


@router.post("/send")
def send_otp(request: OTPSendRequest):
    mobile = request.mobile.strip()

    if not mobile:
        raise HTTPException(
            status_code=400,
            detail="Mobile number is required",
        )

    # Demo OTP.
    # Replace with Firebase/Twilio/SMS provider in production.
    otp = str(random.randint(100000, 999999))

    OTP_STORE[mobile] = {
        "otp": otp,
        "expires_at": datetime.utcnow() + timedelta(minutes=5),
        "verified": False,
    }

    print(f"[DEMO OTP] {mobile}: {otp}")

    return {
        "success": True,
        "message": "OTP generated successfully",
        "expires_in_seconds": 300,
        "demo_otp": otp,
    }


@router.post("/verify")
def verify_otp(request: OTPVerifyRequest):
    mobile = request.mobile.strip()
    otp = request.otp.strip()

    record = OTP_STORE.get(mobile)

    if not record:
        raise HTTPException(
            status_code=400,
            detail="OTP not requested",
        )

    if datetime.utcnow() > record["expires_at"]:
        OTP_STORE.pop(mobile, None)

        raise HTTPException(
            status_code=400,
            detail="OTP expired",
        )

    if record["otp"] != otp:
        raise HTTPException(
            status_code=400,
            detail="Invalid OTP",
        )

    record["verified"] = True

    return {
        "success": True,
        "message": "OTP verified successfully",
        "mobile": mobile,
        "verified": True,
    }
