from pydantic import BaseModel, Field


class SendOTPRequest(BaseModel):
    verification_id: str = Field(
        min_length=10
    )


class VerifyOTPRequest(BaseModel):
    verification_id: str = Field(
        min_length=10
    )

    otp: str = Field(
        min_length=6,
        max_length=6,
        pattern=r"^\d{6}$",
    )